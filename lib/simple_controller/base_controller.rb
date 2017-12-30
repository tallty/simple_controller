class SimpleController::BaseController < ::InheritedResources::Base
  respond_to :json

  def index
    index!( { template: "#{self.class.view_class_path}/index" } )
  end

  def show
    show!( { template: "#{self.class.view_class_path}/show" } )
  end

  def create
    create!( { template: "#{self.class.view_class_path}/show", status: 201 } )
  end

  protected

  mattr_accessor :view_class_path

  def self.view_path path
    self.view_class_path = path
  end

  def view_path
    self.class.view_class_path ||= begin
      controller_class_path = controller_path.split "/"
      if controller_class_path.size > 1
        File.join controller_class_path[0], controller_class_path[-1]
      else
        controller_class_path[-1]
      end
    end
  end

  def collection
    get_collection_ivar || set_collection_ivar(end_of_association_chain.ransack(params[:q]).result.paginate(page: params[:page], per_page: params[:per_page]))
  end
end
