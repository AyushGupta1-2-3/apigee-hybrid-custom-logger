#!/usr/bin/env ruby
# Copyright 2026 Google LLC
# integration/test_processor.rb - Validates log parsing and normalization logic

require 'json'
require 'time'

# -------------------------------------------------------------------------
# MOCK ENVIRONMENT & DATA
# -------------------------------------------------------------------------
MOCK_K8S_METADATA = {
  "namespace_name" => "test-ns",
  "pod_name" => "test-pod",
  "container_name" => "test-cont",
  "node_name" => "test-node",
  "labels" => {
    "com.apigee.apigeedeployment" => "test-app"
  }
}

# -------------------------------------------------------------------------
# REGEX PATTERNS (Mirrored from ConfigMap)
# -------------------------------------------------------------------------
PATTERNS = [
  # klog (Standard)
  {
    name: "klog",
    regex: /^(?<level_klog>[IWEF])\s*(?<time_klog>\d{4}\s+[\d:]+\.\d+)\s+(?<threadid>\d+)\s+(?<file>[^:]+):(?<line>\d+)\]\s*(?<message>.*)/
  },
  # JSON
  {
    name: "json",
    is_json: true
  },
  # logfmt
  {
    name: "logfmt",
    regex: /^ts=(?<time>[^ ]+)\s+caller=(?<caller>[^ ]+)\s+level=(?<level>[^ ]+)\s+(?<message>.*)/
  },
  # Zap / Controller-runtime
  {
    name: "zap",
    regex: /^(?<time>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\s+(?<level>[A-Z]+)\s+(?<message>.*)/
  },
  # Go Standard Library
  {
    name: "gostd",
    regex: /^(?<time>\d{4}\/\d{2}\/\d{2}\s+[\d:]+)\s+(?<message>.*)/
  },
  # Etcd
  {
    name: "etcd",
    regex: /^(?<time>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{6})\s+(?<level>[A-Z])\s+\|\s+(?<message>.*)/
  },
  # Catch-all
  {
    name: "fallback",
    regex: /^(?<message>.*)/
  }
]

# -------------------------------------------------------------------------
# PROCESSING LOGIC
# -------------------------------------------------------------------------

def parse_line(raw_line)
  # Step 1: CRI Parsing (Mocking Fluentd CRI parser)
  # Expected format: <timestamp> <stream> <flag> <content>
  m = raw_line.match(/^(?<time_val>[^ ]+) (?<stream>[^ ]+) (?<flag>[^ ]+) (?<log>.*)$/)
  return nil unless m
  
  record = m.names.zip(m.captures).to_h
  record["kubernetes"] = MOCK_K8S_METADATA
  
  # Step 3: PARSING (Attempt multiple formats)
  content = record["log"]
  parsed_data = nil
  
  PATTERNS.each do |p|
    if p[:is_json]
      begin
        parsed_data = JSON.parse(content)
        break
      rescue JSON::ParserError
        next
      end
    else
      m_inner = content.match(p[:regex])
      if m_inner
        parsed_data = m_inner.names.zip(m_inner.captures).to_h
        break
      end
    end
  end
  
  record.merge!(parsed_data) if parsed_data
  
  # Step 4a: RECORD TRANSFORMER (Normalization)
  record["k8s_ns"]   = record.dig("kubernetes", "namespace_name")
  record["k8s_cont"] = record.dig("kubernetes", "container_name")
  record["k8s_host"] = record.dig("kubernetes", "node_name")
  record["k8s_app"]  = record.dig("kubernetes", "labels", "com.apigee.apigeedeployment") || "unknown"
  
  # Mocking the RUBY block for klog_parts
  log_content = record['log'] || record['message'] || ""
  if (m_klog = log_content.strip.match(/^([IWEF])\s*(\d{4}\s+[\d:]+\.\d+)\s+(\d+)\s+([^:]+):(\d+)\]\s*(.*)/))
    record['klog_parts'] = {level: m_klog[1], time: m_klog[2], thread: m_klog[3], file: m_klog[4], line: m_klog[5], msg: m_klog[6]}
  end
  
  # Step 4b: Final NORMALIZATION
  res_ns   = record["k8s_ns"]
  res_pod  = record.dig("kubernetes", "pod_name")
  res_cont = record["k8s_cont"]
  res_node = record["k8s_host"]
  
  # Robust fallback: use klog_parts if available AND lookup succeeds, otherwise use message/log
  msg_val = record['msg_val'] || (record['klog_parts'] && record['klog_parts']['msg']) || record['msg'] || record['message'] || record['log']
  
  # Severity Mapping
  raw_level = record['level'] || record['level_klog'] || (record['klog_parts'] ? record['klog_parts']['level'] : nil)
  
  sev_val = "INFO"
  if raw_level
    case raw_level.upcase
    when 'I'
      sev_val = 'INFO'
    when 'W'
      sev_val = 'WARN'
    when 'E'
      sev_val = 'ERROR'
    when 'F'
      sev_val = 'FATAL'
    else
      sev_val = raw_level.upcase
    end
  else
    sev_val = ((record['msg'] || record['message'] || record['log'] || "").downcase.include?("error") || record['stream'] == 'stderr' ? 'ERROR' : 'INFO')
  end
  
  # Time Normalization
  time_val = record['ts'] || record['time_val'] || Time.now.strftime('%Y-%m-%dT%H:%M:%S.%NZ')
  if record['time_klog']
    begin
      # klog format doesn't have year, we assume current year for test
      t = Time.strptime(record['time_klog'], '%m%d %H:%M:%S.%N')
      time_val = Time.new(Time.now.year, t.month, t.day, t.hour, t.min, t.sec, t.nsec/1000).strftime('%Y-%m-%dT%H:%M:%S.%NZ')
    rescue => e
      # fallback
    end
  end

  # Packaging
  {
    "resource" => {
      "namespace" => res_ns,
      "pod" => res_pod,
      "container" => res_cont,
      "node" => res_node
    },
    "message" => msg_val,
    "severity" => sev_val,
    "timestamp" => time_val
  }
end

# -------------------------------------------------------------------------
# TEST RUNNER
# -------------------------------------------------------------------------
INPUT_DIR = "tests/integration/fixtures/input"
EXPECTED_DIR = "tests/integration/fixtures/output"
ACTUAL_DIR = "tests/integration/fixtures/actual"

Dir.mkdir(ACTUAL_DIR) unless Dir.exist?(ACTUAL_DIR)

files = Dir.glob("#{INPUT_DIR}/*.log").sort
exit_code = 0

puts "--------------------------------------------------------"
puts "🚀 Running Ruby Log Processor Tests..."
puts "--------------------------------------------------------"

files.each do |file|
  name = File.basename(file, ".log")
  print "Testing format: #{name.ljust(15)}"
  
  raw_line = File.read(file).strip
  result = parse_line(raw_line)
  
  if result.nil?
    puts "  ❌ [FAIL] Failed to parse CRI format"
    exit_code = 1
    next
  end
  
  # Save actual result
  actual_json_str = JSON.pretty_generate(result)
  File.write("#{ACTUAL_DIR}/#{name}.json", actual_json_str)
  
  # Compare with expected result
  expected_file = "#{EXPECTED_DIR}/#{name}.json"
  if File.exist?(expected_file)
    expected_data = JSON.parse(File.read(expected_file))
    
    # We compare message and severity (skip timestamp as it's dynamic/complex)
    if result["message"] == expected_data["message"] && result["severity"] == expected_data["severity"]
      puts "  ✅ [PASS]"
    else
      puts "  ❌ [FAIL] Content mismatch"
      puts "     Expected: msg=\"#{expected_data['message']}\", sev=\"#{expected_data['severity']}\""
      puts "     Actual:   msg=\"#{result['message']}\", sev=\"#{result['severity']}\""
      exit_code = 1
    end
  else
    puts "  ⚠️ [WARN] No expected output file found at #{expected_file}. Generating one..."
    File.write(expected_file, actual_json_str)
  end
end

puts "--------------------------------------------------------"
if exit_code == 0
  puts "✨ ALL PARSING TESTS PASSED!"
else
  puts "🛑 SOME TESTS FAILED!"
end
exit exit_code
