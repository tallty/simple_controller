require 'rails'
require 'actionpack'
require 'activerecord'
require 'activesupport'
require 'active_support/dependencies'
require 'set'

require 'ransack'
require 'inherited_resources'
require 'responders'

module SimpleController
  autoload :VERSION,            'simple_controller/version'
  autoload :Base,               'simple_controller/base'
end
