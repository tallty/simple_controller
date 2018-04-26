json.current_page @resources.current_page
json.total_pages @resources.total_pages

json.<%= resource_plural %> @resources, partial: '<%= view_path %>/simple', as: :<%= resource_singular %>
