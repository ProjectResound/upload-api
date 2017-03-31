require 'resque/server'

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :audios, only: [:create, :index, :get]
    end
  end

  mount Resque::Server.new, at: '/resque'

  mount ActionCable.server => '/cable'
end
