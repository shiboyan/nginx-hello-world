# # encoding: utf-8

# Inspec test for recipe jkodroff_nginx::default

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

describe package('nginx') do
  it { should be_installed }
end

describe port(80) do
  it { should be_listening }
end

# Simulates a request that originated from the client via HTTPS.
describe command('curl http://localhost --header "X-Forwarded-Proto: https"') do
  its('stdout') { should include 'Hello World!' }
end

# Simulates a request that originated from the client via HTTP.
describe command('curl -I http://localhost') do
  its('stdout') { should include '301 Moved Permanently' }
  # Because we're editing the default server, this redirect will fall to "_" as the server name.
  its('stdout') { should include 'https://localhost' }
end