_ = require 'lodash'
http = require 'http'
async = require 'async'
uuid = require 'uuid'

class SendMessage2
  constructor: ({@cache,@datastore,@meshbluConfig,@jobManager}) ->

  do: (job, callback) =>
    {auth, fromUuid, responseId} = job.metadata
    fromUuid ?= auth.uuid
    try
      message = JSON.parse job.rawData
    catch

    @_send {auth, fromUuid, message}, (error) =>
      return @_sendResponse responseId, error.code, callback if error?
      @_sendResponse responseId, 204, callback

  _createJob: ({messageType, jobType, toUuid, message, fromUuid, auth}, callback) =>
    request =
      data: message
      metadata:
        auth: auth
        toUuid: toUuid
        fromUuid: fromUuid
        jobType: jobType
        messageType: messageType
        responseId: uuid.v4()

    @jobManager.createRequest 'request', request, callback

  _isBroadcast: (message) =>
    _.includes message.devices, '*'

  _send: ({fromUuid, message, auth}, callback) =>
    if !message or _.isEmpty message.devices
      error = new Error 'Invalid Message Format'
      error.code = 422
      return callback error

    message.fromUuid = fromUuid

    if _.isString message.devices
      message.devices = [ message.devices ]

    tasks = []

    tasks.push async.apply @_createJob, {
      messageType: 'sent'
      jobType: 'DeliverSentMessage'
      toUuid: fromUuid
      fromUuid: fromUuid
      message: message
      auth: auth
    }

    if @_isBroadcast message
      tasks.push async.apply @_createJob, {
        messageType: 'broadcast'
        jobType: 'DeliverBroadcastSentMessage'
        toUuid: fromUuid
        message: message
        auth: auth
      }

    devices = _.without message.devices, '*'
    _.each devices, (toUuid) =>
      tasks.push async.apply @_createJob, {
        messageType: 'received'
        jobType: 'DeliverReceivedMessage'
        toUuid: toUuid
        fromUuid: fromUuid
        message: message
        auth: auth
      }

    async.series tasks, callback

  _sendResponse: (responseId, code, callback) =>
    callback null,
      metadata:
        responseId: responseId
        code: code
        status: http.STATUS_CODES[code]

module.exports = SendMessage2
