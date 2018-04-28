module SimpleController
  class ResourcesController < ApplicationController
    class << self
      # The base_resources of this controller
      # ActiveRecord::Base or ActiveRecord::Relation
      
      attr_reader :_base_resources

      def base_resources model_or_relation
        @_base_resources = model_or_relation
      end

      def klass
        _base_resources < ActiveRecord::Base ? _base_resources : _base_resources.klass
      end

      # The view template dir
      # respond_with @products, template: "#{view_path}/index"

      def view_path path
        @_view_path = path
      end

      def _view_path
        @_view_path ||= default_view_path
      end
      
      # Refuse to search methods in superclasses
      def remove_actions *actions
        actions.each { |name| remove_possible_method name }
      end
      
      def parents
        @parents || {}
      end
      
      def belongs_to reflection, param_key: nil
        ref = klass.reflections[reflection.to_s]
        raise ArgumentError.new("Undefine reflection: #{reflection}.") unless ref
        @parents = parents.merge(
          (param_key || ref.foreign_key) => { klass: ref.klass, foreign_key: ref.foreign_key }
        )
      end

      def default_view_path
       controller_class_path = controller_path.split "/"
        if controller_class_path.size > 1
          File.join controller_class_path[0], controller_class_path[-1]
        else
          controller_class_path[-1]
        end
      end
    end

    before_action :set_resource, only: [:show, :update, :destroy]
    
    respond_to :json
    
    rescue_from SimpleController::Error do |e|
      Rails.logger.error e.message
      e.backtrace.each { |line| Rails.logger.info line }
      render json: { error: e.message, code: e.code }, status: e.status
    end

    rescue_from ActiveRecord::RecordInvalid, ArgumentError do |e|
      render json: { error: e.message }, status: 400
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      render json: { error: e.message }, status: 404
    end

    rescue_from AASM::InvalidTransition do |e|
      render json: { error: e.message }, status: 400
    end

    def index
      page = params[:page] || 1
      per_page = params[:per_page] || 10
      @resources = index_resources.ransack(params[:q]).result.distinct.paginate(page: page, per_page: per_page)
      render_index
    end

    def show
      render_show
    end

    def create
      @resource = default_resources.create!(resource_params)
      render_show status: 201
    end

    def update
      @resource.update!(resource_params)
      head 200
    end

    def destroy
      @resource.destroy!
      head 204
    end
    
    attr_accessor :base_resources, :view_path

    def initialize
      super
      @base_resources = self.class._base_resources
      @view_path      = self.class._view_path
    end

    private
      # Instance method: default_query
      #   example: 
      #     def default_query resources
      #       resources.where(product_id: params[:product_id])
      #     end
      # default_query would be useful for create & set_resource
      #   Just like:
      #     one_product.series.create! => default_query where(product_id: params[:product_id])
      # 

      def default_query resources
        resources
      end

      # Add the index query to custom the @@index_resouces on the base of @@resources
      # Foe example: 
      #
      #   def index_query resources
      #     resources.where(product: params[:product_id]).order('desc')
      #   end
      #

      def index_query resources
        resources
      end

      def index_resources
        index_query(default_resources)
      end

      def default_resources
        try_parents(default_query(base_resources))
      end

      def resource_key
        @resource_key ||= (default_resources.try(:klass) || default_resources).model_name.singular.to_sym
      end

      def set_resource
        @resource = default_resources.find(params[:id])
      end
      
      def try_parents resources
        self.class.parents.reduce(resources) { |relation, key_and_val| 
          param_key, val = key_and_val
          param_val      = params[param_key]
          relation.where(
            param_val && { val[:foreign_key] => val[:klass].find(param_val).id }
          )
        }
      end

      # If you want to add custome columns, you can do just like:
      #   def resource_params
      #     super&.merge params.require(:some_key)
      #   end

      def resource_params
        params.require(resource_key)
      end

      def render_show status: 200
        respond_with @resource, template: "#{view_path}/show", status: status
      end

      def render_index status: 200
        respond_with @resources, template: "#{view_path}/index", status: status
      end
  end
end