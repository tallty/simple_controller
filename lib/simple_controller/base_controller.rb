class SimpleController::BaseController < ::InheritedResources::Base
  respond_to :json

  def index
    index!
  end

  def show
    show!
  end

  def create
    create!
  end

  def index!(options={}, &block)
    options = { template: "#{self.class.view_path}/index" }.merge options
    super(options, &block)
  end

  def show!(options={}, &block)
    options = { template: "#{self.class.view_path}/show" }.merge options
    super(options, &block)
  end

  def create!(options={}, &block)
    options = { template: "#{self.class.view_path}/show", status: 201 }.merge options
    super(options, &block)
  end

  def import
    xlsx_file = params[:file]
    response = import_class.import_xlsx xlsx_file, collection, params.to_unsafe_h
    render json: response, status: 201
  end

  def export
    url = export_class.export_xlsx collection, params.to_unsafe_h
    render json: { url: url }, status: 201
  end

  protected

  class << self
    def view_path
      @view_path
    end

    def defaults(options)
      view_path = options.delete(:view_path)
      @ransack_off = options.delete(:ransack_off)
      @paginate_off = options.delete(:paginate_off)

      set_view_path view_path if view_path.present?
      super(options)

      self.class_attribute :import_class, instance_writer: false unless self.respond_to? :import_class
      self.class_attribute :export_class, instance_writer: false unless self.respond_to? :export_class
      self.import_class = options.delete(:import_class) || self.resource_class
      self.export_class = options.delete(:export_class) || self.resource_class
    end

    def set_view_path path
      @view_path = path
    end
  end

  def view_path
    self.class.instance_variable_get(:@view_path) ||
      self.class.instance_variable_set(:@view_path, extract_view_path)
  end

  def extract_view_path
    controller_class_path = controller_path.split "/"
    if controller_class_path.size > 1
      File.join controller_class_path[0], controller_class_path[-1]
    else
      controller_class_path[-1]
    end
  end

  def after_association_chain association
    association
  end

  def ransack_paginate(association)
    association = association.ransack(params[:q]).result.distinct unless self.class.instance_variable_get(:@ransack_off)
    association = association.paginate(page: params[:page], per_page: params[:per_page]) unless self.class.instance_variable_get(:@paginate_off)
    association
  end

  def collection
    get_collection_ivar || set_collection_ivar(
      ransack_paginate(after_association_chain(end_of_association_chain))
    )
  end

  def permitted_params
    action_resource_params_method_name = "#{params[:action]}_#{resource_params_method_name}"
    respond_to?(action_resource_params_method_name, true) ?
      {resource_request_name => send(action_resource_params_method_name)} :
      {resource_request_name => send(resource_params_method_name)}
  rescue ActionController::ParameterMissing
    # typically :new action
    if params[:action].to_s == 'new'
      {resource_request_name => {}}
    else
      raise
    end
  end
end
