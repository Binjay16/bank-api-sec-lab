Rails.application.routes.draw do
  post "login",  to: "sessions#create"
  get  "logout", to: "sessions#destroy"

  resources :users, only: %i[index show create]

  resources :accounts, only: %i[index show] do
    collection { get :lookup }
    get "statement/export", to: "statements#export"
  end

  resources :transfers, only: %i[index create]

  get "statements/download", to: "statements#download"
  put "preferences",         to: "preferences#update"
  get "reports/:type",       to: "reports#show"
end
