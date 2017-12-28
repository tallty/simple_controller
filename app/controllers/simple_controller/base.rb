class SimpleController::Base < ::InheritedResources::Base
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

  def self.view_path path
    @view_class_path = path
  end

  def self.view_class_path
    @view_class_path
  end

  def collection
    get_collection_ivar || set_collection_ivar(end_of_association_chain.ransack(params[:q]).result.paginate(page: params[:page], per_page: params[:per_page]))
  end
end
