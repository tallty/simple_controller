json.current_page @<%= plural_name %>.current_page
json.total_page @<%= plural_name %>.total_pages

json.<%= plural_name %> @<%= plural_name %>, partial: '<%= view_class_path %>/simple', as: :<%= singular_name %>
