class SimpleController::BaseController < ::InheritedResources::Base
  respond_to :json

  def index
    index!( { template: "#{self.class.view_path}/index" } )
  end

  def show
    show!( { template: "#{self.class.view_path}/show" } )
  end

  def create
    create!( { template: "#{self.class.view_path}/show", status: 201 } )
  end

  protected

  class << self
    def view_path
      @view_path
    end

    def defaults(options)
      view_path = options.delete(:view_path)
      set_view_path view_path if view_path.present?
      super(options)
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
    association.ransack(
      params[:q]
    ).result.distinct.paginate(
      page: params[:page], per_page: params[:per_page]
    )
  end

  def collection
    get_collection_ivar || set_collection_ivar(
      ransack_paginate(after_association_chain(end_of_association_chain))
    )
  end
end
