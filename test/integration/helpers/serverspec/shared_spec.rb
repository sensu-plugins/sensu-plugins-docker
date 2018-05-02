# frozen_string_literal: true

require 'spec_helper'

shared_examples_for 'ruby checks' do |check|
  describe command('which ruby') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/\/usr\/local\/bin\/ruby/) }
  end

  describe command('which gem') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/\/usr\/local\/bin\/gem/) }
  end

  describe command("which #{check}") do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(Regexp.new(Regexp.escape(check))) }
  end

  describe file(check) do
    it { should be_file }
    it { should be_executable }
  end
end
