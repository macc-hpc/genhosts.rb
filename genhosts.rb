#!/usr/bin/env ruby
require 'csv'
require 'erb'
require 'optparse'
require 'fileutils'

REQUIRED = [:i, :o, :t]

compute = []
ib_over_ip = []
management = []

Host = Struct.new(:hostname, :address, :mac)
config = {}

opts = ARGV.options do |opts|
  opts.banner = "Usage: #{__FILE__} -t template.erb -i input.csv -o output.txt"

  opts.on('-t TEMPLATE', 'ERB template') do |value|
    unless File.exists?(value)
      warn('Template file missing')
      exit
    end
    config[:t] = value
  end

  opts.on('-i INPUT', 'Input file in CSV format') do |value|
    unless File.exists?(value)
      warn('Input file missing')
      exit
    end
    config[:i] = value
  end

  opts.on('-o OUTPUT', 'Output file. Will overwrite existing file')
  opts.on('-m', 'Output one file per host')

  opts.on('-h', 'Prints this help') do
    puts opts
    exit
  end
end

begin
  opts.parse!(into: config)
rescue OptionParser::MissingArgument => e
  warn(e)
end

opts.parse('-h') unless REQUIRED & config.keys == REQUIRED

CSV.foreach(config[:i]) do |row|
  row.compact!

  break if row.empty? || row.length < 3

  management << Host.new(*row[0..2])
  ib_over_ip << Host.new(*row[3..5])
  compute << Host.new(*row[6..8])
end

class PerHost
  def initialize(hosts, template)
    @hosts = hosts
    @renderer = ERB.new(File.read(template), trim_mode: '-')
  end

  def render
    @renderer.result(binding)
  end

  def write(filename)
    @hosts.each do |host|
      @host = host
      path = File.join(File.dirname(filename), host.hostname)
      FileUtils.mkdir_p(path) unless File.exists?(path)
      open(File.join(path, File.basename(filename) ), 'w') { |f| f << render }
    end
  end
end

class SingleFile
  def initialize(hosts, template)
    @hosts = hosts
    @renderer = ERB.new(File.read(template), trim_mode: '-')
  end

  def render
    @renderer.result(binding)
  end

  def write(filename)
    open(filename, 'w') { |f| f << render }
  end
end

if config.has_key?(:m)
  PerHost.new(ib_over_ip, config[:t]).write(config[:o])
else
  SingleFile.new([].concat(management, ib_over_ip, compute), config[:t]).write(config[:o])
end
