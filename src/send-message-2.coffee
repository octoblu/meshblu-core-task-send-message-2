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

    if _.includes devices, '*'
      return @_deliverBroadcastSent {message, auth, fromUuid}, (error) =>
        return @_sendResponse responseId, (error.code || 500), callback if error?
        @_sendResponse responseId, 204, callback

    @_deliverMessagesSent {message, auth, fromUuid, devices}, callback

  _deliverMessagesSent: ({message, auth, fromUuid, devices}, callback) =>
    async.eachSeries devices, (device, callback) =>
      @_deliverMessageSent({
        message: message
        auth: auth
        fromUuid: fromUuid
        toUuid: device
      }, callback)
    , callback

  _deliverMessageSent: ({message, auth, fromUuid, toUuid}, callback) =>
    console.log {message, auth, fromUuid, toUuid}
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
