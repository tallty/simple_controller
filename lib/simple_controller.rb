require 'rails'
require 'active_record'

require 'responders'
require 'ransack'
require 'inherited_resources'

module SimpleController
  autoload :VERSION,            'simple_controller/version'
  autoload :BaseController,               'simple_controller/base_controller'
end
