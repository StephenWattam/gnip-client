#!/usr/bin/env ruby
#
# Gnip historical job submission/management tool.
# Steve Wattam <steve@stephenwattam.com> 16/05/16
#
# ---------------------------------------------------------
# Configure the constants below to match your gnip setup.
#
# Your account name
API_ACCOUNT_NAME = 'LancasterUniversity'
# This is the gnip API endpoint
API_ENDPOINT = "https://historical.gnip.com/accounts/#{API_ACCOUNT_NAME}/"


# (Don't edit below here)
# =========================================================
# Support procedures
#

EXAMPLE_JOB = 'ewogICAgInB1Ymxpc2hlciIgICAgIDogInR3aXR0ZXIiLAogICAgInN0cmVhbVR5cGUiICAgIDogInRyYWNrIiwKICAgICJkYXRhRm9ybWF0IiAgICA6ICJhY3Rpdml0eS1zdHJlYW1zIiwKICAgICJmcm9tRGF0ZSIgICAgICA6ICIyMDE2MDExMzAwMDAiLAogICAgInRvRGF0ZSIgICAgICAgIDogIjIwMTYwMTEzMDEwMCIsCiAgICAidGl0bGUiICAgICAgICAgOiAiVGVzdCBqb2IiLAogICAgInJ1bGVzIiA6IFsKICAgICAgICB7IlZhbHVlIjogInRlYXBvdCJ9IAogICAgXQp9Cgo='

require 'json'
require 'net/http'
require 'uri'
require 'base64'
require 'openssl'
require 'zlib'
require 'resolv-replace.rb' # Use a ruby DNS resolver

# Make a HTTP request to a JSON API,
# returning the result as an object
def get_json(endpoint, username = nil, password = nil, endpoint_stub = API_ENDPOINT)
  uri = URI("#{endpoint_stub}#{endpoint}")

  res = ''
  Net::HTTP.start(uri.host, uri.port,
                  :use_ssl => uri.scheme == 'https', 
                  :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
    req = Net::HTTP::Get.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    req.basic_auth(username, password) if username && password

    res = http.request(req)
  end

  JSON.parse(res.body.to_s)
end

# Make a HTTP PUT request
def put_json(endpoint, payload, username = nil, password = nil, endpoint_stub = API_ENDPOINT)
  uri = URI("#{endpoint_stub}#{endpoint}")

  res = ''
  Net::HTTP.start(uri.host, uri.port,
                  :use_ssl => uri.scheme == 'https', 
                  :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
    req = Net::HTTP::Put.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    req.basic_auth(username, password) if username && password
    req.body = payload.to_json

    res = http.request(req)
  end

  JSON.parse(res.body.to_s)
end


# make a POST request
def post_json(endpoint, payload, username = nil, password = nil, endpoint_stub = API_ENDPOINT)
  uri = URI("#{endpoint_stub}#{endpoint}")

  res = ''
  Net::HTTP.start(uri.host, uri.port,
                  :use_ssl => uri.scheme == 'https', 
                  :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
    req = Net::HTTP::Post.new(uri.request_uri)
    req.basic_auth(username, password) if username && password
    req['Content-Type'] = 'application/json'
    req.body = payload.to_json

    res = http.request(req)
  end

  JSON.parse(res.body.to_s)
end

# Retrieve a job from a UUID
def get_job(uuid, username, password)
  jobs = get_json('jobs.json', username, password)
  job = jobs['jobs'].find { |j| j['uuid'] == uuid }

  if job['jobURL']
    job.merge!(get_json(job['jobURL'], username, password, ''))
  end

  fail "Could not find job with UUID=#{uuid}" unless job
  job
end

# Turn a hash into a human-readable description
def summarise_job(job, indent = 0)
  s = StringIO.new
  s.puts "Gnip ID:    #{job['uuid'] || '(no ID yet)'}"
  s.puts "Title:      \"#{job['title']}\""
  s.puts "From #{job['fromDate']} to #{job['toDate']}"
  s.puts "Publisher:  #{job['publisher']}"
  s.puts "Rules:      #{job['rules']}" if job['rules']
  # s.puts "URL:        #{job['jobURL']}" if job['jobURL']
  s.puts "Requested:  by #{job['requestedBy']} at #{job['requestedAt']}" if job['requestedBy']
  s.puts "Status:     #{job['status']}: #{job['statusMessage']}" if job['status']
  s.puts "Completion: #{job['percentComplete']}%" if job['percentComplete']

  if job['quote']
    s.puts "Estimate:   #{job['quote']['estimatedActivityCount']} activities"
    s.puts "            #{job['quote']['estimatedDurationHours']} hours"
    s.puts "            #{job['quote']['estimatedFileSizeMb']} MB"
    s.puts "            expires at #{job['quote']['expiresAt']}"
  end
  if job['results']
    r = job['results']
    s.puts "Results:    #{r['activityCount']} activities"
    s.puts "            #{r['fileSizeMb']} MB (#{r['fileCount']} files)"
    s.puts "            Completed #{r['completedAt']}, expires #{r['expiresAt']}"
  end

  str = ''
  s.string.lines.each do |l|
    str += (' ' * indent) + l
  end

  str
end


# List jobs currently active for the 
def list_jobs(username, password, uuid = nil)
  jobs = get_json('jobs.json', username, password)
  puts ""
  jobs["jobs"].each do |job|
    next if uuid && job['uuid'] != uuid
    if job['jobURL']
      job.merge!(get_json(job['jobURL'], username, password, ''))
    end
    puts summarise_job(job, 2)
    puts ""
  end
  del = jobs['delivered']
  puts "#{del['jobCount']} jobs, #{del['activityCount']} activities delivered since #{del['since']}"
end

# Post a new job
def new_job(job, username, password)
  puts "Requesting quote for job:"
  puts JSON.pretty_generate(job)
  puts ""
  res = post_json('jobs.json', job, username, password)
  if res['error'] || res['status'] == 'error'
    puts "Job rejected (error #{res['status']}): #{res['error'] || res['reason']}"
    return
  end

  puts "Gnip's job desc:"
  puts summarise_job(res)
end

# Accept a job
def start_job(uuid, username, password, accept = true)
  puts "#{accept ? 'Accept' : 'Reject'}ing job #{uuid}"
  
  # Retrieve job
  job = get_job(uuid, username, password)
  puts "Job info:"
  puts summarise_job(job, 2)
  puts ""

  if job['status'] == 'rejected'
    puts "Job has already been rejected."
    return
  end

  # Tell thingy to do start things.
  payload = {"status" => (accept ? "accept" : "reject")}
  res = put_json(job['jobURL'], payload, username, password, '')

  puts "Job status: #{res['status']}: #{res['statusMessage']}"
end

# Download stuff from a job
def download_job(uuid, out_fn, username, password)
  puts "Downloading data from job #{uuid} to #{out_fn}"
  fail "Output file exists!" if File.exist?(out_fn)

  job = get_job(uuid, username, password)
  puts "Job info:"
  puts summarise_job(job, 2)
  puts ""

  # Download stuff.
  puts "Retrieving index..."
  index = get_json(job['results']['dataURL'], username, password, '')

  num_files = index['urlCount']
  puts "Retrieving #{num_files} files..."
  
  i = 0
  File.open(out_fn, 'w') do |out|
    index['urlList'].each do |url|
      i += 1
      print " #{i} / #{num_files} (#{((i.to_f / num_files.to_f) * 100.0).round(2)}%)      \r"

      begin
        # RAW HTTP get request
        res = Net::HTTP.get(URI(url))
        zlibr = Zlib::GzipReader.new(StringIO.new(res.to_s))
        out.puts zlibr.read
      rescue StandardError => e
        print "\n*** ERR on file #{i}, URL: #{url}\n"
      end
      
    end # /url iteration
  end # /file handle

  print "Done\n"
end



# =========================================================
# Entry point
subcommand = ARGV.shift
if !subcommand || subcommand.downcase == 'help' 

  warn "USAGE: #{$0} SUBCOMMAND [ARGS]"
  warn ""
  warn "Available subcommands:"
  warn "  list UNAME PASS [JOB_ID]: list all current jobs.  Optional filter"
  warn "  new JOB_FILE UNAME PASS: get a quote for a new job"
  warn "  accept JOB_ID UNAME PASS: accept (start) a quoted job"
  warn "  reject JOB_ID UNAME PASS: reject a quoted job"
  warn "  download JOB_ID OUT_FILE UNAME PASS: download files from a completed job to DIR"
  warn "  help : show this help"
  warn ""
  warn "To configure this script, edit the constants"
  warn "at the top of the file."
  warn ""
  warn "Job file format"
  warn "---------------"
  warn "Job files are JSON, following the gnip request"
  warn "format, e.g.: "
  warn Base64.decode64(EXAMPLE_JOB)

  exit(1)
end
subcommand = subcommand.to_sym


case subcommand
  when :list
    uname = ARGV.shift
    pass = ARGV.shift
    uuid = ARGV.shift
    list_jobs(uname, pass, uuid)
  when :new
    job = JSON.parse(File.read(ARGV.shift))
    uname = ARGV.shift
    pass = ARGV.shift
    new_job(job, uname, pass)
  when :accept
    uuid = ARGV.shift
    uname = ARGV.shift
    pass = ARGV.shift
    start_job(uuid, uname, pass, true)
  when :reject
    uuid = ARGV.shift
    uname = ARGV.shift
    pass = ARGV.shift
    start_job(uuid, uname, pass, false)
  when :download
    uuid = ARGV.shift
    out_fn = ARGV.shift
    uname = ARGV.shift
    pass = ARGV.shift
    download_job(uuid, out_fn, uname, pass)
  else
    warn "Unknown subcommand: '#{subcommand}'"
end








