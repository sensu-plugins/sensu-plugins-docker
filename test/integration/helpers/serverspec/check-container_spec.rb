# frozen_string_literal: true

require 'spec_helper'
require 'shared_spec'

gem_path = '/usr/local/bin'
check_name = 'check-container.rb'
check = "#{gem_path}/#{check_name}"

describe 'ruby environment' do
  it_behaves_like 'ruby checks', check
end

describe command("#{check} -N test_running") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/CheckDockerContainer OK: test_running is running on unix:\/\/\/var\/run\/docker.sock./) }
end

describe command("#{check} -x -N test_running") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/CheckDockerContainer OK: test_running is running on unix:\/\/\/var\/run\/docker.sock./) }
end

describe command("#{check} -N test_exited_ok") do
  its(:exit_status) { should eq 2 }
  its(:stdout) { should match(/CheckDockerContainer CRITICAL: test_exited_ok is exited on unix:\/\/\/var\/run\/docker.sock./) }
end

describe command("#{check} -x -N test_exited_ok") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/CheckDockerContainer OK: test_exited_ok has exited without error on unix:\/\/\/var\/run\/docker.sock./) }
end

describe command("#{check} -x -N test_exited_fail") do
  its(:exit_status) { should eq 2 }
  its(:stdout) { should match(/CheckDockerContainer CRITICAL: test_exited_fail has exited with status code 1 on unix:\/\/\/var\/run\/docker.sock./) }
end
