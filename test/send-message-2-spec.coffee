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
            fromUuid: 'falcon-punch'
            responseId: 'response-uuid'
            auth:
              uuid:  'sender-uuid'
              token: 'sender-token'
          rawData: JSON.stringify devices: ['*']

        @sut.do request, (error, @response) => done error

      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, @request) => done error

      it 'should respond with a 204', ->
        expect(@response.metadata.code).to.equal 204

      it 'should create the right kinda DeliverBroadcastSent job', ->
        expect(@request.metadata).to.containSubset
          jobType: 'DeliverBroadcastSent'
          messageType: 'broadcast-sent'
          toUuid: 'falcon-punch'

    context 'when devices is ["some-dumb-uuid"]', ->
      beforeEach (done) ->
        @requestMap = {}
        request =
          metadata:
            fromUuid: 'falcon-punch'
            responseId: 'response-uuid'
            auth:
              uuid:  'sender-uuid'
              token: 'sender-token'
          rawData: JSON.stringify devices: ['some-dumb-uuid']

        @sut.do request, (error, @response) => done error

      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          @requestMap[request.metadata.jobType] = request
          done error

      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          @requestMap[request.metadata.jobType] = request
          done error

      it 'should create the right kinda DeliverMessageSent job', ->
        expect(@requestMap['DeliverMessageSent'].metadata).to.containSubset
          jobType: 'DeliverMessageSent'
          messageType: 'message-sent'
          fromUuid: 'falcon-punch'
          toUuid: 'some-dumb-uuid'

      it 'should create the right kinda DeliverMessageReceived job', ->
        expect(@requestMap['DeliverMessageReceived'].metadata).to.containSubset
          jobType: 'DeliverMessageReceived'
          messageType: 'message-received'
          fromUuid: 'falcon-punch'
          toUuid: 'some-dumb-uuid'

    context 'when devices has a uuid and a "*" for broadcast (["*", "some-dumb-uuid"])', ->
      beforeEach (done) ->
        @requestMap = {}
        request =
          metadata:
            fromUuid: 'falcon-punch'
            responseId: 'response-uuid'
            auth:
              uuid:  'sender-uuid'
              token: 'sender-token'
          rawData: JSON.stringify devices: ['some-dumb-uuid', '*']

        @sut.do request, (error, @response) => done error

      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          @requestMap[request.metadata.jobType] = request
          done error

      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          @requestMap[request.metadata.jobType] = request
          done error

      beforeEach (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          @requestMap[request.metadata.jobType] = request
          done error

      it 'should create the right kinda DeliverMessageSent job', ->
        expect(@requestMap['DeliverMessageSent'].metadata).to.containSubset
          jobType: 'DeliverMessageSent'
          messageType: 'message-sent'
          fromUuid: 'falcon-punch'
          toUuid: 'some-dumb-uuid'

      it 'should create the right kinda DeliverMessageReceived job', ->
        expect(@requestMap['DeliverMessageReceived'].metadata).to.containSubset
          jobType: 'DeliverMessageReceived'
          messageType: 'message-received'
          fromUuid: 'falcon-punch'
          toUuid: 'some-dumb-uuid'

      it 'should create the right kinda DeliverBroadcastSent job', ->
        expect(@requestMap['DeliverBroadcastSent'].metadata).to.containSubset
          jobType: 'DeliverBroadcastSent'
          messageType: 'broadcast-sent'
          toUuid: 'falcon-punch'
