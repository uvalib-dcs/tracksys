Tracksys::Application.routes.draw do
  root :to => 'requests#index'
  get "request" => 'requests#index'
  ActiveAdmin.routes(self)

  # See notes inside... had to do some workarounds to get routes/controlers
  # working as needed within the ActiveAdmin bounds. A bit ugly, but oh well.
  namespace :admin do
     # There is no activeAdmin workstation resource page defined. The
     # functionality is blended into a general equipment page. The JS
     # for this page calls create, update and destroy endpoints on a
     # workstation object. Created a separate (normal) rails controller
     # to handle these requests. Routes registerd here
     resources :workstations, only: [:create, :update, :destroy]
     delete "workstations/:id/equipment" => "workstations#clear_equipment"
     delete "items/:id" => "items#destroy"
     post "items/convert" => "items#convert"
     post "items/metadata" => "items#create_metadata"

     post "messages/:id/read" => "messages#read_meassge"
     delete "messages/:id" => "messages#destroy"
     post "messages" => "messages#create"

     # archivesSpace
     post "archivesspace/validate" => "archivesspace#validate"
     get "archivesspace/lookup" => "archivesspace#lookup"
     post "archivesspace/convert" => "archivesspace#convert"

     # Weird. The file /admin/equipment is made with register_page so it
     # has none of the basic CRUD actions defined automatically. Add them
     # here manually
     resources :equipment, only: [:destroy, :create, :update]
  end

  namespace :api do
     get "archivesspace/report" => "as#report"
     get "metadata/search" => "metadata#search"
     post "xml/validate" => "xml#validate"
     post "xml/generate" => "xml#generate"
     post "jstor" => "jstor#finalize"
  end
end
