'use strict';

const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');

const sns = new SNSClient({});

exports.handler = async (event = {}) => {
  const topicArn = process.env.TOPIC_ARN;

  if (!topicArn) {
    throw new Error('TOPIC_ARN environment variable is required');
  }

  const body = parseBody(event.body);
  const message = body.message ?? 'Hello from the producer Lambda';

  const result = await sns.send(
    new PublishCommand({
      TopicArn: topicArn,
      Message: JSON.stringify({
        message,
        createdAt: new Date().toISOString(),
      }),
    }),
  );

  return {
    statusCode: 200,
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      message: 'Message published to SNS',
      messageId: result.MessageId,
    }),
  };
};

function parseBody(body) {
  if (!body) {
    return {};
  }

  if (typeof body === 'object') {
    return body;
  }

  try {
    return JSON.parse(body);
  } catch {
    return { message: body };
  }
}
