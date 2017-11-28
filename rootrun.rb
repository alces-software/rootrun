#!/usr/bin/env ruby
#==============================================================================
# Copyright (C) 2017 Stephen F. Norledge and Alces Software Ltd.
#
# This file/package is part of Alces Repoman.
#
# Alces Repoman is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# Alces Repoman is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this package.  If not, see <http://www.gnu.org/licenses/>.
#
# For more information on the Alces Repoman, please visit:
# https://github.com/alces-software/repoman
#==============================================================================

#==============#
# System Setup #
#==============#
require 'yaml'
require 'fileutils'
require 'timeout'
require 'etc'
$LOAD_PATH << File.dirname(__FILE__)

#===================#
# Program Variables #
#===================#
$rootdir = '/opt/rootrun'
cfg_load = YAML.load_file($rootdir + '/rootrun.yaml')
$completed_scripts_file = $rootdir + '/.scripts_complete.yaml'

$scriptdir = cfg_load['scriptdir']
$userlogdir = cfg_load['userlogdir']
$adminlogdir = cfg_load['adminlogdir']
$interval = cfg_load['interval']
$timeout = cfg_load['timeout']
$groups = [`hostname -s`.strip, cfg_load['groups'], 'all']

#==============#
# Script Class #
#==============#
class Script
  def initialize(full_script_path)
    @script = full_script_path
    @script_name = full_script_path.sub(/^.*\//, '')
    @user_script_log = File.open($userlogdir + "/#{@script_name}.log", "w")
    @user_script_log.sync = true
    @admin_script_log = File.open($adminlogdir + "/#{@script_name}.log", "w")
    @admin_script_log.sync = true
  end

  def puts_all(text)
    puts text
    @user_script_log.puts text
    @admin_script_log.puts text
  end

  def run()
    if ! $scripts_complete['scripts'].include? @script
      self.puts_all("Running #{@script} (owner: #{Etc.getpwuid(File.stat(@script).uid).name}) - saving script output to #{@user_script_log.path} and #{@admin_script_log.path}")
      if self._run_sub
        self.puts_all("Successfully ran #{@script} - marking as complete")
        $scripts_complete['scripts'] << @script
      end
    else
#      self.puts_all("Skipping #{@script} - this script has been run before")
    end
    @user_script_log.close
    @admin_script_log.close
  end

  def _run_sub()
    self.puts_all("Sub process for running #{@script_name} - #{Time.now.inspect}")
    # Lock file

    # Run script
    rcommand_out, wcommand_out = IO.pipe
    pid = Process.spawn("/bin/bash #{@script}", {[:out,:err] => wcommand_out})
    begin
      Timeout.timeout($timeout) do
        Process.wait(pid)
      end

    rescue Timeout::Error
      self.puts_all("Killing #{@script} - maximum timeout (#{$timeout}s) reached")
      Process.kill('TERM', pid)
      return false

    ensure
      wcommand_out.close
      self.puts_all(rcommand_out.readlines.join("\n"))
      rcommand_out.close
    end

    self.puts_all("Finished running sub process for #{@script_name} - #{Time.now.inspect}")
    return true
  end
end

#===========#
# Functions #
#===========#
def mkdir_wrapper(dir)
  if ! File.directory?(dir)
    begin
      FileUtils::mkdir_p dir

      rescue SystemCallError
        STDERR.puts "An error occurred when creating #{dir}, most likely the user has insufficient permissions to create the directory"
        exit 1
    end
  end
end

def program_setup
  # Creates directories required for the program to work
  $groups.compact.each do |groupdir|
    mkdir_wrapper("#{$scriptdir}/#{groupdir}")
  end
  FileUtils.chmod_R(0777, $scriptdir) # Make script directory user accessible
  mkdir_wrapper($userlogdir)
  mkdir_wrapper($adminlogdir)

  # Sync output instead of buffer
  $stdout.sync = true

  # Create scripts file if it doesn't exist
  if ! File.file?($completed_scripts_file)
    File.write($completed_scripts_file, 'scripts: []')
  end
end

def rootrun_main
  puts "ROOTRUN START - #{Time.now.inspect}"
  $scripts_complete = YAML.load_file($completed_scripts_file)
  # Locate all script files in groups, 'compact' removes 'nil' from array preventing top-level listing
  scripts = Dir[$scriptdir + "/{#{$groups.compact.join(',')}}/*"].reject {|fn| File.directory?(fn) }.map
  scripts.each do |script|
    script_instance = Script.new(script)
    script_instance.run
  end
  File.write($completed_scripts_file, $scripts_complete.to_yaml)
  puts "ROOTRUN COMPLETE - Sleeping for #{$interval} seconds"
  sleep($interval)
end

#=============#
# Run Program #
#=============#
program_setup()

while true do
  rootrun_main()
end
