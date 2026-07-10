Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"

  get "about" => "pages#about"
  get "contact" => "pages#contact"

  resources :case_studies, only: %i[index show], path: "case-studies", param: :slug
  resources :writings, only: %i[index show], path: "writing", param: :slug
end
