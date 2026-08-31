Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :admin_users, path: "admin/session"

  namespace :admin do
    root "dashboard#index"
    post "share_links" => "share_links#create", as: :share_links
    delete "share_links/:id" => "share_links#revoke", as: :revoke_share_link
    resources :knowledge_entries, only: %i[index update]
    resources :opportunities, only: %i[index show]
  end

  get "ask" => "ask#show"
  post "api/ask/questions" => "api/ask/questions#create"
  post "api/job_search/opportunities/submit" => "api/job_search/opportunities#submit"
  get "api/job_search/opportunities/engagements" => "api/job_search/engagements#index"
  post "api/job_search/token_pool/refill" => "api/job_search/token_pool#refill"

  root "pages#home"

  get "about" => "pages#about"
  get "contact" => "pages#contact"

  resources :case_studies, only: %i[index show], path: "case-studies", param: :slug
  resources :writings, only: %i[index show], path: "writing", param: :slug
  resources :tags, only: %i[index show], param: :slug
end
