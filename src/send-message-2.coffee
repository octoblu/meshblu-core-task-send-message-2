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
      return @_sendResponse responseId, 422, callback

    {devices} = message
    return @_sendResponse responseId, 422, callback unless devices?

    request =
      metadata:
        auth: auth
        fromUuid: fromUuid
        jobType: 'DeliverBroadcastSent'
        responseId: uuid.v4()

    @jobManager.createRequest 'request', request, (error) =>
      return @_sendResponse responseId, error.code, callback if error?
      @_sendResponse responseId, 204, callback


  _sendResponse: (responseId, code, callback) =>
    callback null,
      metadata:
        responseId: responseId
        code: code
        status: http.STATUS_CODES[code]

module.exports = SendMessage2
