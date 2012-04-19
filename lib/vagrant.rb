require 'log4r'

# Enable logging if it is requested. We do this before
# anything else so that we can setup the output before
# any logging occurs.
if ENV["VAGRANT_LOG"] && ENV["VAGRANT_LOG"] != ""
  # Require Log4r and define the levels we'll be using
  require 'log4r/config'
  Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

  level = nil
  begin
    level = Log4r.const_get(ENV["VAGRANT_LOG"].upcase)
  rescue NameError
    # This means that the logging constant wasn't found,
    # which is fine. We just keep `level` as `nil`. But
    # we tell the user.
    level = nil
  end

  # Some constants, such as "true" resolve to booleans, so the
  # above error checking doesn't catch it. This will check to make
  # sure that the log level is an integer, as Log4r requires.
  level = nil if !level.is_a?(Integer)

  if !level
    # We directly write to stderr here because the VagrantError system
    # is not setup yet.
    $stderr.puts "Invalid VAGRANT_LOG level is set: #{ENV["VAGRANT_LOG"]}"
    $stderr.puts ""
    $stderr.puts "Please use one of the standard log levels: debug, info, warn, or error"
    exit 1
  end

  # Set the logging level on all "vagrant" namespaced
  # logs as long as we have a valid level.
  if level
    logger = Log4r::Logger.new("vagrant")
    logger.outputters = Log4r::Outputter.stderr
    logger.level = level
    logger = nil
  end
end

require 'pathname'
require 'childprocess'
require 'json'
require 'i18n'

# OpenSSL must be loaded here since when it is loaded via `autoload`
# there are issues with ciphers not being properly loaded.
require 'openssl'

# Always make the version available
require 'vagrant/version'
Log4r::Logger.new("vagrant::global").info("Vagrant version: #{Vagrant::VERSION}")

module Vagrant
  autoload :Action,        'vagrant/action'
  autoload :Box,           'vagrant/box'
  autoload :BoxCollection, 'vagrant/box_collection'
  autoload :CLI,           'vagrant/cli'
  autoload :Command,       'vagrant/command'
  autoload :Communication, 'vagrant/communication'
  autoload :Config,        'vagrant/config'
  autoload :DataStore,     'vagrant/data_store'
  autoload :Downloaders,   'vagrant/downloaders'
  autoload :Driver,        'vagrant/driver'
  autoload :Environment,   'vagrant/environment'
  autoload :Errors,        'vagrant/errors'
  autoload :Guest,         'vagrant/guest'
  autoload :Hosts,         'vagrant/hosts'
  autoload :Plugin,        'vagrant/plugin'
  autoload :Provisioners,  'vagrant/provisioners'
  autoload :Registry,      'vagrant/registry'
  autoload :SSH,           'vagrant/ssh'
  autoload :TestHelpers,   'vagrant/test_helpers'
  autoload :UI,            'vagrant/ui'
  autoload :Util,          'vagrant/util'
  autoload :VM,            'vagrant/vm'

  # Returns a `Vagrant::Registry` object that contains all the built-in
  # middleware stacks.
  def self.actions
    @actions ||= Vagrant::Action::Builtin.new
  end

  # The source root is the path to the root directory of
  # the Vagrant gem.
  def self.source_root
    @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
  end

  # Returns a superclass to use when creating a plugin for Vagrant.
  # Given a specific version, this returns a proper superclass to use
  # to register plugins for that version.
  #
  # Plugins should subclass the class returned by this method, and will
  # be registered as soon as they have a name associated with them.
  #
  # @return [Class]
  def self.plugin(version)
    # We only support version 1 right now.
    return Plugin::V1 if version == "1"

    # Raise an error that the plugin version is invalid
    raise ArgumentError, "Invalid plugin version API: #{version}"
  end

  # Global registry of commands that are available via the CLI.
  #
  # This registry is used to look up the sub-commands that are available
  # to Vagrant.
  def self.commands
    @commands ||= Registry.new
  end
end

# # Default I18n to load the en locale
I18n.load_path << File.expand_path("templates/locales/en.yml", Vagrant.source_root)

# Load the core plugins that ship with Vagrant
Vagrant.source_root.join("plugins").each_child do |directory|
  # We only care about directories
  next if !directory.directory?

  # We only care if there is a plugin file within the directory
  plugin_file = directory.join("plugin.rb")
  next if !plugin_file.file?

  # Load the plugin!
  load(plugin_file)
end

# Register the built-in commands
Vagrant.commands.register(:box)          { Vagrant::Command::Box }
Vagrant.commands.register(:destroy)      { Vagrant::Command::Destroy }
Vagrant.commands.register(:gem)          { Vagrant::Command::Gem }
Vagrant.commands.register(:halt)         { Vagrant::Command::Halt }
Vagrant.commands.register(:init)         { Vagrant::Command::Init }
Vagrant.commands.register(:package)      { Vagrant::Command::Package }
Vagrant.commands.register(:provision)    { Vagrant::Command::Provision }
Vagrant.commands.register(:reload)       { Vagrant::Command::Reload }
Vagrant.commands.register(:resume)       { Vagrant::Command::Resume }
Vagrant.commands.register(:ssh)          { Vagrant::Command::SSH }
Vagrant.commands.register(:"ssh-config") { Vagrant::Command::SSHConfig }
Vagrant.commands.register(:status)       { Vagrant::Command::Status }
Vagrant.commands.register(:suspend)      { Vagrant::Command::Suspend }
Vagrant.commands.register(:up)           { Vagrant::Command::Up }
