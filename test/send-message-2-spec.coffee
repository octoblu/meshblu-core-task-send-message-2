_ = require 'lodash'
SendMessage2 = require '..'
redis  = require 'fakeredis'
RedisNS = require '@octoblu/redis-ns'
uuid   = require 'uuid'
JobManager = require 'meshblu-core-job-manager'

describe 'SendMessage2', ->
  beforeEach ->
    @redisKey = uuid.v1()
    @pubSubKey = uuid.v1()
    sendMessageJobManager = new JobManager
      client: new RedisNS 'whatever', redis.createClient @pubSubKey
      timeoutSeconds: 1
    @jobManager = new JobManager
      client: new RedisNS 'whatever', redis.createClient @pubSubKey
      timeoutSeconds: 1
    @sut = new SendMessage2
      client: new RedisNS 'whatever', redis.createClient @redisKey
      meshbluConfig: {uuid: 'meshblu-uuid', token: 'meshblu-token'}
      jobManager: sendMessageJobManager

  describe '->do', ->
    context 'when devices is missing', ->
      beforeEach (done) ->
        request =
          metadata:
            responseId: 'response-uuid'
            auth:
              uuid:  'sender-uuid'
              token: 'sender-token'
          rawData: JSON.stringify({})

        @sut.do request, (error, @response) => done error

      it 'should respond with a 422', ->
        expect(@response.metadata.code).to.equal 422

    context 'when rawData is null', ->
      beforeEach (done) ->
        request =
          metadata:
            responseId: 'response-uuid'
            auth:
              uuid:  'sender-uuid'
              token: 'sender-token'

        @sut.do request, (error, @response) => done error

      it 'should respond with a 422', ->
        expect(@response.metadata.code).to.equal 422

    context 'when devices is ["*"]', ->
      beforeEach (done) ->
        request =
          metadata:
            responseId: 'response-uuid'
            auth:
              uuid:  'sender-uuid'
              token: 'sender-token'
          rawData: JSON.stringify devices: ['*']

        @sut.do request, (error, @response) => done error

      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, @request) =>
          done error

      it 'should respond with a 204', ->
        expect(@response.metadata.code).to.equal 204

      it 'should create a job', ->
        expect(@request).to.exist

      it 'should create a job', ->
        expect(@request.metadata.jobType).to.equal 'DeliverBroadcastSent'

      xdescribe 'JobManager gets DeliverBroadcastSent job', (done) ->
        beforeEach (done) ->
          @jobManager.getRequest ['request'], (error, @request) =>
            done error

        it 'should be a sent messageType', ->
          message =
            devices: ['*']
            fromUuid: 'sender-uuid'

          auth =
            uuid: 'sender-uuid'
            token: 'sender-token'

          {rawData, metadata} = @request
          expect(metadata.auth).to.deep.equal auth
          expect(metadata.jobType).to.equal 'DeliverSentMessage'
          expect(metadata.fromUuid).to.equal 'sender-uuid'
          expect(metadata.messageType).to.equal 'sent'
          expect(metadata.toUuid).to.equal 'sender-uuid'
          expect(rawData).to.equal JSON.stringify message

        describe 'JobManager gets DeliverBroadcastSentMessage job', (done) ->
          beforeEach (done) ->
            @jobManager.getRequest ['request'], (error, @request) =>
              done error

          it 'should be a broadcast messageType', ->
            message =
              devices: ['*']
              fromUuid: 'sender-uuid'

            auth =
              uuid: 'sender-uuid'
              token: 'sender-token'

            {rawData, metadata} = @request
            expect(metadata.auth).to.deep.equal auth
            expect(metadata.jobType).to.equal 'DeliverBroadcastSentMessage'
            expect(metadata.fromUuid).to.equal 'sender-uuid'
            expect(metadata.messageType).to.equal 'broadcast'
            expect(metadata.toUuid).to.equal 'sender-uuid'
            expect(rawData).to.equal JSON.stringify message
