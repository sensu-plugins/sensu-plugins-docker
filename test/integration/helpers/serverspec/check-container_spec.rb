# frozen_string_literal: true

require 'spec_helper'
require 'shared_spec'

gem_path = '/usr/local/bin'
check_name = 'check-container.rb'
check = "#{gem_path}/#{check_name}"

describe 'ruby environment' do
  it_behaves_like 'ruby checks', check
end

describe command("#{check} -N test") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/CheckDockerContainer OK: test is running on unix:\/\/\/var\/run\/docker.sock./) }
end
