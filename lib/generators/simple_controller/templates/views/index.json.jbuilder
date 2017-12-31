json.current_page @<%= resource_plural %>.current_page
json.total_page @<%= resource_plural %>.total_pages

json.<%= resource_plural %> @<%= resource_plural %>, partial: '<%= view_path %>/simple', as: :<%= resource_singular %>
