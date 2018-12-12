json.current_page @<%= resource_plural %>.current_page
json.total_pages @<%= resource_plural %>.total_pages
json.total_count @<%= resource_plural %>.count

json.<%= resource_plural %> @<%= resource_plural %>, partial: '<%= view_path %>/simple', as: :<%= resource_singular %>
