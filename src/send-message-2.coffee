_ = require 'lodash'
http = require 'http'
async = require 'async'
uuid = require 'uuid'

class SendMessage2
  constructor: ({@cache,@datastore,@meshbluConfig,@jobManager}) ->

  do: (job, callback) =>
    {auth, fromUuid, responseId} = job.metadata
    fromUuid ?= auth.uuid
    message = undefined

    try
      message = JSON.parse job.rawData
    catch
      return @_sendResponse responseId, 422, callback
    {devices} = message

    return @_sendResponse responseId, 422, callback unless devices?

    @_createJobs {message, auth, fromUuid, devices}, (error) =>
      return @_sendResponse responseId, (error.code || 500), callback if error?
      @_sendResponse responseId, 204, callback


  _createJobs: ({message, auth, fromUuid, devices}, callback) =>
    async.eachSeries devices, (device, callback) =>
      job =
        message: message
        auth: auth
        fromUuid: fromUuid
        toUuid: device
      return @_deliverBroadcastSent(job, callback) if device == '*'
      @_deliverMessage(job, callback)
    , callback

  _deliverMessage: ({message, auth, fromUuid, toUuid}, callback) =>    
    requestSent =
      data: message
      metadata:
        auth: auth
        fromUuid: fromUuid
        toUuid: toUuid
        jobType: 'DeliverMessageSent'
        messageType: 'message-sent'
        responseId: uuid.v4()

    requestReceived =
      data: message
      metadata:
        auth: auth
        fromUuid: fromUuid
        toUuid: toUuid
        jobType: 'DeliverMessageReceived'
        messageType: 'message-received'
        responseId: uuid.v4()

    @jobManager.createRequest 'request', requestSent, (error) =>
      @jobManager.createRequest 'request', requestReceived, callback

  _deliverBroadcastSent: ({message, auth, fromUuid}, callback) =>
    request =
      data: message
      metadata:
        auth: auth
        toUuid: fromUuid
        jobType: 'DeliverBroadcastSent'
        messageType: 'broadcast-sent'
        responseId: uuid.v4()

    @jobManager.createRequest 'request', request, callback

  _sendResponse: (responseId, code, callback) =>
    callback null,
      metadata:
        responseId: responseId
        code: code
        status: http.STATUS_CODES[code]

module.exports = SendMessage2
