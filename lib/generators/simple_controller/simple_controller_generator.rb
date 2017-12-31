class SimpleControllerGenerator < Rails::Generators::NamedBase
  include Rails::Generators::ResourceHelpers

  source_root File.expand_path('../templates', __FILE__)

  class_option :view, type: :string, desc: "View files generate folder"
  class_option :model, type: :string, desc: "Model name for extract attributes"
  class_option :auth, type: :string, desc: "Authentication model name"
  class_option 'no-swagger', type: :boolean, desc: "Do not generate swagger spec file"

  def setup
    @routes = RSpec::Rails::Swagger::RouteParser.new(controller_path.sub(/^\//, '')).routes
    p "Warning!! Resource is not exist, CHECK & regenerate after you have configurate the model and routes already" if resource_class&.columns_hash.blank?
  end

  def create_controller_files
    template_file = "controllers/controller.rb"
    template template_file, File.join("app/controllers", controller_class_path, "#{controller_file_name}_controller.rb")
  end

  def copy_view_files
    %w(index show _single _simple _detail).each do |view|
      filename = filename_with_extensions(view)
      template "views/#{filename}", File.join('app/views', view_path, filename)
    end
  end

  def create_swagger_files
    return if options["no-swagger"]
    template_file = "specs/spec.rb"
    template template_file, File.join("spec/requests", controller_class_path, "#{controller_file_name}_spec.rb")
  end

  protected

  def view_path
    return options.view if options.view.present?
    if controller_class_path.size > 1
      File.join controller_class_path[0], plural_name
    else
      plural_name
    end
  end

  def controller_path
    File.join controller_class_path, plural_name
  end

  def auth
    options.auth&.camelcase if options.auth.present?
  end

  def response_status action
    case action
    when 'get'
      200
    when 'post'
      201
    else
      204
    end
  end

  def resource_class
    @resource_class ||= begin
      options.model.constantize if options.model.present?
    rescue NameError
      nil
    end

    @resource_class ||= begin
      namespaced_class = controller_class_name.singularize
      namespaced_class.constantize
    rescue NameError
      nil
    end

    # Second priority is the top namespace model, e.g. EngineName::Article for EngineName::Admin::ArticlesController
    @resource_class ||= begin
      namespaced_classes = controller_class_name.split('::')
      namespaced_class = [namespaced_classes.first, namespaced_classes.last].join('::').singularize
      namespaced_class.constantize
    rescue NameError
      nil
    end

    # Third priority the camelcased c, i.e. UserGroup
    @resource_class ||= begin
      camelcased_class = controller_class_name.singularize
      camelcased_class.constantize
    rescue NameError
      nil
    end

    # Otherwise use the Group class, or fail
    @resource_class ||= begin
      class_name = controller_class_name.classify
      class_name.constantize
    rescue NameError => e
      raise unless e.message.include?(class_name)
      nil
    end
    @resource_class
  end

  def resource_plural
    resource_class&.model_name&.plural
  end

  def resource_singular
    resource_class&.model_name&.singular
  end

  def attributes_names
    begin
      resource_class.columns.map(&:name) - %w(id created_at updated_at)
    rescue NameError
      []
    end
  end

  def filename_with_extensions(name)
    [name, :json, :jbuilder] * '.'
  end

  def attributes_list_with_timestamps
    attributes_list(%w(id created_at updated_at) + attributes_names)
  end

  def attributes_list(attributes = attributes_names)
    attributes.map { |a| ":#{a}"} * ', '
  end
end
