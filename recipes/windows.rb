# Author:: David Laing <david@davidlaing.com>
# Cookbook Name:: ntp
# Recipe:: windows
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

unless platform? "windows"
  raise ArgumentError, 'This recipe can only be run on Windows nodes' 
end

service_user = node["ntp"]["service_user"]
service_password = node["ntp"]["service_password"] 

ntp_install_settings = "#{ENV['TEMP']}\\ntpd_installer_settings.ini"
ntp_install_dir = "#{ENV['ProgramFiles']}\\NTP"
ntp_config_dir  = "#{ntp_install_dir}\\etc"
ntp_config_file = "#{ntp_config_dir}\\ntp.conf"

template "#{ntp_install_settings}" do
  source "ntpd_installer_settings.ini.erb"
  variables(
    :ntp_config_file => ntp_config_file,
    :ntp_install_dir => ntp_install_dir,
    :service_user => service_user,
    :service_password => service_password
  )
end

directory "#{ntp_install_dir}" do
  action :create
end

directory "#{ntp_config_dir}" do
  action :create
end

template "#{ntp_config_file}" do
  source "ntpd_config.conf.erb"
  variables(
    :ntp_install_dir => ntp_install_dir
  )
end

windows_batch "IFF on EC2, break the dependancy of Ec2Config on W32Time, so that NTPd can start" do
  code <<-EOH
  sc config Ec2Config depend= /
  EOH
  only_if { node.attribute?('ec2') }
end

windows_package "Network Time Protocol" do
  source "http://www.meinberg.de/download/ntp/windows/ntp-4.2.4p8@lennon-o-lpv-win32-setup.exe"
  options "/USEFILE=\"#{ntp_install_settings}\""
  action :install
end

windows_batch "IFF on EC2, set Ec2Config to depend NTP instead of W32Time" do
  code <<-EOH
  sc config Ec2Config depend= NTP
  EOH
  only_if { node.attribute?('ec2') }
end

windows_package "NTP Time Server Monitor 1.04" do
  source "http://www.meinberg.de/download/ntp/windows/time-server-monitor/ntp-time-server-monitor.exe"
  action :install
end

#And a useful utility for inspecting loopstats and peerstats files
windows_zipfile "#{ntp_install_dir}\\bin" do
  source "http://satsignal.eu/software/NTPplotter.zip"
  action :unzip
  not_if {::File.exists?("#{ntp_install_dir}\\bin\\NTPplotter.exe")}
end
