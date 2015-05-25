# encoding: utf-8

module Guard
  class Slim
    class Notifier
      class << self
        def image result
          result ? :success : :failed
        end

        def notify( result, message )
          ::Guard::Notifier.notify( message,
                                    title: 'Guard::Slim',
                                    image: image( result )
                                  )
        end
      end
    end
  end
end
