# SimpleController

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/simple_controller`. To experiment with that code, run `bin/console` for an interactive prompt.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simple_controller', git: 'git://github.com/tallty/simple_controller'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install simple_controller

## Usage

You should create model and prepare the routes ready, then you can simple
generate controller, views, swagger spec files by the simple command.

```ruby
# default model is Demand::Service or Service
# default view path is demand/services
rails g simple_controller demand/admin/service
```

```ruby
# with authentication
rails g simple_controller demand/admin/service --auth=admin
```

```ruby
# with model name
rails g simple_controller demand/admin/service --model=Other::Service
```

```ruby
# with view folder name
rails g simple_controller demand/admin/service --view=demand/admin/service
```

```ruby
# without swagger spec file
rails g simple_controller demand/admin/service --no-swagger
```

Another option is to specify which actions the controller will inherit from
the `SimpleController::BaseController`:

```ruby
class ProjectsController < SimpleController::BaseController
  actions :index, :show, :new, :create
end
```

Or:

```ruby
class ProjectsController < SimpleController::BaseController
  actions :all, except: [ :edit, :update, :destroy ]
end
```

In your views, you will get the following helpers:

```ruby
resource        #=> @project
collection      #=> @projects
resource_class  #=> Project
```

As you might expect, collection (`@projects` instance variable) is only
available
on index actions.

## Overwriting defaults

Whenever you inherit from SimpleController, several defaults are assumed.
For example you can have an `AccountsController` for account management while
the
resource is a `User`:

```ruby
class AccountsController < SimpleController::BaseController
  defaults resource_class: User, collection_name: 'users', instance_name: 'user'
end
```

In the case above, in your views you will have `@users` and `@user` variables,
but the routes used will still be `accounts_url` and `account_url`. If you plan also
to change the routes, you can use `:route_collection_name` and `:route_instance_name`.

Namespaced controllers work out of the box, but if you need to specify a
different route prefix you can do the following:

```ruby
class Administrators::PeopleController < SimpleController::BaseController
  defaults route_prefix: 'admin'
end
```

Then your named routes will be: `admin_people_url`, `admin_person_url` instead
of `administrators_people_url` and `administrators_person_url`.

If you want to customize how resources are retrieved you can overwrite
collection and resource methods. The first is called on index action and the
second on all other actions. Let's suppose you want to add pagination to your
projects collection:

```ruby
class ProjectsController < SimpleController::BaseController
  protected
    def collection
      get_collection_ivar ||
set_collection_ivar(end_of_association_chain.paginate(page: params[:page]))
    end
end
```

The `end_of_association_chain` returns your resource after nesting all
associations and scopes (more about this below).

The `after_association_chain` add some scope or relation codes for the
`end_of_association_chain`:

```ruby
  def after_association_chain association
    association.top  #top is the scope
  end
```

SimpleController also introduces another method called `begin_of_association_chain`.
It's mostly used when you want to create resources based on the `@current_user` and
you have urls like "account/projects". In such cases you have to do
`@current_user.projects.find` or `@current_user.projects.build` in your actions.

You can deal with it just by doing:

```ruby
class ProjectsController < SimpleController::BaseController
  protected
    def begin_of_association_chain
      @current_user
    end
end
```

## Overwriting actions

Let's suppose that after destroying a project you want to redirect to your
root url instead of redirecting to projects url. You just have to do:

```ruby
class ProjectsController < SimpleController::BaseController
  def destroy
    super do |format|
      format.html { redirect_to root_url }
    end
  end
end
```

You are opening your action and giving the parent action a new behavior. On
the other hand, I have to agree that calling super is not very readable. That's
why all methods have aliases. So this is equivalent:

```ruby
class ProjectsController < SimpleController::BaseController
  def destroy
    destroy! do |format|
      format.html { redirect_to root_url }
    end
  end
end
```

Since most of the time when you change a create, update or destroy
action you do so because you want to change its redirect url, a shortcut is
provided. So you can do:

```ruby
class ProjectsController < SimpleController::BaseController
  def destroy
    destroy! { root_url }
  end
end
```

If you simply want to change the flash message for a particular action, you can
pass the message to the parent action using the keys `:notice` and `:alert` (as
you
would with flash):

```ruby
class ProjectsController < SimpleController::BaseController
  def create
    create!(notice: "Dude! Nice job creating that project.")
  end
end
```

You can still pass the block to change the redirect, as mentioned above:

```ruby
class ProjectsController < SimpleController::BaseController
  def create
    create!(notice: "Dude! Nice job creating that project.") { root_url }
  end
end
```

Now let's suppose that before create a project you have to do something special
but you don't want to create a before filter for it:

```ruby
class ProjectsController < SimpleController::BaseController
  def create
    @project = Project.new(params[:project])
    @project.something_special!
    create!
  end
end
```

Yes, it's that simple! The nice part is since you already set the instance
variable
`@project`, it will not build a project again.

Same goes for updating the project:

```ruby
class ProjectsController < SimpleController::BaseController
  def update
    @project = Project.find(params[:id])
    @project.something_special!
    update!
  end
end
```

Before we finish this topic, we should talk about one more thing:
"success/failure
blocks". Let's suppose that when we update our project, in case of failure, we
want to redirect to the project url instead of re-rendering the edit template.

Our first attempt to do this would be:

```ruby
class ProjectsController < SimpleController::BaseController
  def update
    update! do |format|
      unless @project.errors.empty? # failure
        format.html { redirect_to project_url(@project) }
      end
    end
  end
end
```

Looks too verbose, right? We can actually do:

```ruby
class ProjectsController < SimpleController::BaseController
  def update
    update! do |success, failure|
      failure.html { redirect_to project_url(@project) }
    end
  end
end
```

Much better! So explaining everything: when you give a block which expects one
argument it will be executed in both scenarios: success and failure. But if you
give a block that expects two arguments, the first will be executed only in
success scenarios and the second in failure scenarios. You keep everything
clean and organized inside the same action.

## Smart redirects

Although the syntax above is a nice shortcut, you won't need to do it frequently
because (since version 1.2) Inherited Resources has smart redirects. Redirects
in actions calculates depending on the existent controller methods.

Redirects in create and update actions calculates in the following order:
`resource_url`,
`collection_url`, `parent_url` (which we are going to see later), and
`root_url`. Redirect
in destroy action calculate in following order `collection_url`, `parent_url`,
`root_url`.

Example:

```ruby
class ButtonsController < SimpleController::BaseController
  belongs_to :window
  actions :all, except: [:show, :index]
end
```

This controller redirect to parent window after all CUD actions.

## Success and failure scenarios on destroy

The destroy action can also fail, this usually happens when you have a
`before_destroy` callback in your model which returns false. However, in
order to tell SimpleController that it really failed, you need to add
errors to your model. So your `before_destroy` callback on the model should
be something like this:

```ruby
def before_destroy
  if cant_be_destroyed?
    errors.add(:base, "not allowed")
    false
  end
end
```

## Belongs to

Finally, our Projects are going to get some Tasks. Then you create a
`TasksController` and do:

```ruby
class TasksController < SimpleController::BaseController
  belongs_to :project
end
```

`belongs_to` accepts several options to be able to configure the association.
For example, if you want urls like "/projects/:project_title/tasks", you can
customize how SimpleController find your projects:

```ruby
class TasksController < SimpleController::BaseController
  belongs_to :project, finder: :find_by_title!, param: :project_title
end
```

It also accepts `:route_name`, `:parent_class` and `:instance_name` as options.
Check the
[lib/inherited_resources/class_methods.rb](https://github.com/activeadmin/inherited_resources/blob/master/lib/inherited_resources/class_methods.rb)
for more.

## Nested belongs to

Now, our Tasks get some Comments and you need to nest even deeper. Good
practices says that you should never nest more than two resources, but sometimes
you have to for security reasons. So this is an example of how you can do it:

```ruby
class CommentsController < SimpleController::BaseController
  nested_belongs_to :project, :task
end
```

If you need to configure any of these belongs to, you can nest them using
blocks:

```ruby
class CommentsController < SimpleController::BaseController
  belongs_to :project, finder: :find_by_title!, param: :project_title do
    belongs_to :task
  end
end
```

Warning: calling several `belongs_to` is the same as nesting them:

```ruby
class CommentsController < SimpleController::BaseController
  belongs_to :project
  belongs_to :task
end
```

In other words, the code above is the same as calling `nested_belongs_to`.

## Polymorphic belongs to

We can go even further. Let's suppose our Projects can now have Files, Messages
and Tasks, and they are all commentable. In this case, the best solution is to
use polymorphism:

```ruby
class CommentsController < SimpleController::BaseController
  belongs_to :task, :file, :message, polymorphic: true
  # polymorphic_belongs_to :task, :file, :message
end
```

You can even use it with nested resources:

```ruby
class CommentsController < SimpleController::BaseController
  belongs_to :project do
    belongs_to :task, :file, :message, polymorphic: true
  end
end
```

The url in such cases can be:

```
/project/1/task/13/comments
/project/1/file/11/comments
/project/1/message/9/comments
```

When using polymorphic associations, you get some free helpers:

```ruby
parent?         #=> true
parent_type     #=> :task
parent_class    #=> Task
parent          #=> @task
```

Right now, Inherited Resources is limited and does not allow you
to have two polymorphic associations nested.

## Optional belongs to

Later you decide to create a view to show all comments, independent if they
belong
to a task, file or message. You can reuse your polymorphic controller just
doing:

```ruby
class CommentsController < SimpleController::BaseController
  belongs_to :task, :file, :message, optional: true
  # optional_belongs_to :task, :file, :message
end
```

This will handle all those urls properly:

```
/comment/1
/tasks/2/comment/5
/files/10/comment/3
/messages/13/comment/11
```

This is treated as a special type of polymorphic associations, thus all helpers
are available. As you expect, when no parent is found, the helpers return:

```ruby
parent?         #=> false
parent_type     #=> nil
parent_class    #=> nil
parent          #=> nil
```

## Singletons

Now we are going to add manager to projects. We say that `Manager` is a
singleton
resource because a `Project` has just one manager. You should declare it as
`has_one` (or resource) in your routes.

To declare an resource of current controller  as singleton, you just have to
give the
`:singleton` option in defaults.

```ruby
class ManagersController < SimpleController::BaseController
  defaults singleton: true
  belongs_to :project
  # singleton_belongs_to :project
end
```

So now you can use urls like "/projects/1/manager".

In the case of nested resources (when some of the can be singletons) you can
declare it separately

```ruby
class WorkersController < SimpleController::BaseController
  #defaults singleton: true #if you have only single worker
  belongs_to :project
  belongs_to :manager, singleton: true
end
```

This is correspond urls like "/projects/1/manager/workers/1".

It will deal with everything again and hide the action :index from you.

## Namespaced Controllers

Namespaced controllers works out the box.

```ruby
class Forum::PostsController < SimpleController::BaseController
end
```

Inherited Resources prioritizes the default resource class for the namespaced
controller in
this order:

```
Forum::Post
ForumPost
Post
```

## URL Helpers

When you use SimpleController it creates some URL helpers.
And they handle everything for you. :)

```ruby
# /posts/1/comments
resource_url               # => /posts/1/comments/#{@comment.to_param}
resource_url(comment)      # => /posts/1/comments/#{comment.to_param}
new_resource_url           # => /posts/1/comments/new
edit_resource_url          # => /posts/1/comments/#{@comment.to_param}/edit
edit_resource_url(comment) # => /posts/1/comments/#{comment.to_param}/edit
collection_url             # => /posts/1/comments
parent_url                 # => /posts/1

# /projects/1/tasks
resource_url               # => /projects/1/tasks/#{@task.to_param}
resource_url(task)         # => /projects/1/tasks/#{task.to_param}
new_resource_url           # => /projects/1/tasks/new
edit_resource_url          # => /projects/1/tasks/#{@task.to_param}/edit
edit_resource_url(task)    # => /projects/1/tasks/#{task.to_param}/edit
collection_url             # => /projects/1/tasks
parent_url                 # => /projects/1

# /users
resource_url               # => /users/#{@user.to_param}
resource_url(user)         # => /users/#{user.to_param}
new_resource_url           # => /users/new
edit_resource_url          # => /users/#{@user.to_param}/edit
edit_resource_url(user)    # => /users/#{user.to_param}/edit
collection_url             # => /users
parent_url                 # => /
```

Those urls helpers also accepts a hash as options, just as in named routes.

```ruby
# /projects/1/tasks
collection_url(page: 1, limit: 10) #=> /projects/1/tasks?page=1&limit=10
```

In polymorphic cases, you can also give the parent as parameter to
`collection_url`.

Another nice thing is that those urls are not guessed during runtime. They are
all created when your application is loaded (except for polymorphic
associations, that relies on Rails' `polymorphic_url`).

## Custom actions

Since version 1.2, Inherited Resources allows you to define custom actions in
controller:

```ruby
class ButtonsController < SimpleController::BaseController
  custom_actions resource: :delete, collection: :search
end
```

This code creates delete and search actions in controller (they behaves like
show and
index actions accordingly). Also, it will produce `delete_resource_{path,url}`
and
`search_resources_{path,url}` url helpers.

## What about views?

Sometimes just DRYing up the controllers is not enough. If you need to DRY up
your views,
check this Wiki page:

https://github.com/activeadmin/inherited_resources/wiki/Views-Inheritance


Notice that Rails 3.1 ships with view inheritance built-in.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/simple_controller.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
