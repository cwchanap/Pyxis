#!/usr/bin/env ruby
# Converts `xcrun xccov view --archive` output into LCOV for Codecov.

root = File.expand_path(ARGV.shift || Dir.pwd)
app_source_prefix = File.join(root, "Pyxis") + File::SEPARATOR

current_path = nil
line_hits = []

def emit_record(path, line_hits)
  return if path.nil? || line_hits.empty?

  covered = line_hits.count { |(_, hits)| hits.positive? }

  puts "SF:#{path}"
  line_hits.each do |line, hits|
    puts "DA:#{line},#{hits}"
  end
  puts "LF:#{line_hits.length}"
  puts "LH:#{covered}"
  puts "end_of_record"
end

ARGF.each_line do |raw_line|
  line = raw_line.chomp

  if (match = line.match(%r{\A(/.*\.swift):\z}))
    emit_record(current_path, line_hits)

    absolute_path = File.expand_path(match[1])
    current_path = if absolute_path.start_with?(app_source_prefix)
      absolute_path.delete_prefix(root + File::SEPARATOR)
    end
    line_hits = []
    next
  end

  next if current_path.nil?

  match = line.match(/\A\s*(\d+):\s+(\*|\d+)/)
  next if match.nil? || match[2] == "*"

  line_hits << [match[1].to_i, match[2].to_i]
end

emit_record(current_path, line_hits)
