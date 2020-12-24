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

  def upload_excel
    excel = importable_class.import_excel_klass.new
    excel.load(params[:file])
    render json: { uid: excel.uid }
  end

  def excel
    excel = importable_class.import_excel_klass.new(params[:uid])
    pagination = excel.records_pagination(page: params[:page] || 1, per_page: params[:per_page] || 15)
    render json: {
      current_page: pagination.current_page,
      total_pages: pagination.total_pages,
      total_count: pagination.count,
      titles: excel.titles,
      records: pagination,
    }
  end

  def import
    xlsx_file = params[:file] || importable_class.import_excel_klass.new(params[:uid])
    response = importable_class.import_xlsx(xlsx_file, collection, **params.to_unsafe_h)
    render json: response, status: 201
  end

  def export
    url = exportable_class.export_xlsx collection, **params.to_unsafe_h
    render json: { url: url }, status: 201
  end

  def batch_destroy
    collection.transaction do
      params[:ids].each do |id|
        collection.find(id).destroy!
      end
    end
  end

  def batch_create
    success_count = 0
    error_count = 0
    if params[:transition]
      collection.transition do
        batch_create_params.each do |resource_params|
          collection.create! resource_params
          success_count += 1
        end
      end
    else
      batch_create_params.each do |resource_params|
        begin
          collection.create! resource_params
          success_count += 1
        rescue
          error_count += 1
        end
      end
    end
    render json: { success_count: success_count, error_count: error_count }, status: 201
  end

  def batch_update
    success_count = 0
    error_count = 0
    if params[:transition]
      collection.transition do
        collection.where(id: params[:ids]).update! resource_params
      end
      success_count = collection.count
    else
      collection.where(id: params[:ids]).find_each do |_recourse|
        begin
          _recourse.update! resource_params
          success_count += 1
        rescue
          error_count += 1
        end
      end
    end
    render json: { success_count: success_count, error_count: error_count }, status: 201
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

      self.class_attribute :importable_class, instance_writer: false unless self.respond_to? :importable_class
      self.class_attribute :exportable_class, instance_writer: false unless self.respond_to? :exportable_class
      self.importable_class = options.delete(:importable_class) || self.resource_class
      self.exportable_class = options.delete(:exportable_class) || self.resource_class
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
