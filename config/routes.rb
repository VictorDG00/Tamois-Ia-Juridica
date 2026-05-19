Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  root "pages#home"

  resources :analyses, only: %i[new create show index] do
    member { get :download }
    resource :chat, only: %i[show create]
  end

  get "dashboard" => "dashboard#index", as: :dashboard

  get "up" => "rails/health#show", as: :rails_health_check
end
