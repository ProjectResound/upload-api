module Api::V1
  class AudiosController < BaseController
    include Secured

    before_action :find_audio, only: [:show]

    def index
      if params[:filename]
        @audio = Audio.by_filename(params[:filename])
      elsif params[:working_on] == 'true'
        @audio = Audio.where(uploader_id: @current_user.id).order('created_at DESC').limit(3)
      else
        @audio = Audio.all
      end
      render json: @audio
    end

    def show
      render json: @audio
    end

    def create
      save_file!
      if last_chunk?
        Audio.update_or_create_by_filename(
                 filename: params[:flowFilename],
                 contributor: params[:contributor],
                 title: params[:title],
                 tags: params[:tags],
                 uploader: @current_user
        )

        AudioProcessing.perform_later(
            { identifier: params[:flowIdentifier],
              filename: params[:flowFilename],
              title: params[:title],
              contributor: params[:contributor] }
        )
      end
      render status: :ok
    end

    def search
      results = AudioSearchEngine.search(params[:q])
      render json: results
    end

    private

    def find_audio
      @audio = Audio.find(params[:id])
    end

    def save_file!
      # Ensure required paths exist
      FileUtils.mkpath chunk_file_directory
      # Move the temporary file upload to the temporary chunk file path
      FileUtils.mv params['file'].tempfile, chunk_file_path(params[:flowFilename], params[:flowChunkNumber]), force: true
    end

    def last_chunk?
      for i in 1..params[:flowTotalChunks].to_i
        if !File.exists?(chunk_file_path(params[:flowFilename], i))
          return false
        end
      end
      return true
    end

    def chunk_file_path(fileName, number)
      File.join(chunk_file_directory, "#{fileName}.part#{number}")
    end

    def chunk_file_directory
      File.join "tmp", "flow", params[:flowIdentifier]
    end
  end
end