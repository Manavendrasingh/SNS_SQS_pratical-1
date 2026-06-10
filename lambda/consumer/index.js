'use strict';

exports.handler = async (event = {}) => {
  const records = event.Records ?? [];

  for (const record of records) {
    const message = parseSqsMessage(record.body);

    console.log('Received message:', {
      messageId: record.messageId,
      body: message,
    });
  }

  return {
    batchItemFailures: [],
  };
};

function parseSqsMessage(body) {
  if (!body) {
    return {};
  }

  try {
    const parsedBody = JSON.parse(body);

    if (parsedBody.Message) {
      return JSON.parse(parsedBody.Message);
    }

    return parsedBody;
  } catch {
    return body;
  }
}
