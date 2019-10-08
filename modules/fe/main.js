const AWS = require("aws-sdk");

const ddb = new AWS.DynamoDB({region: process.env.TABLE_REGION});
const sns = new AWS.SNS();

const getPaginatedResults = async (fn) => {
	const EMPTY = Symbol("empty");
	const res = [];
	for await (const lf of (async function*() {
		let NextMarker = EMPTY;
		while (NextMarker || NextMarker === EMPTY) {
			const {marker, results} = await fn(NextMarker !== EMPTY ? NextMarker : undefined);

			yield* results;
			NextMarker = marker;
		}
	})()) {
		res.push(lf);
	}

	return res;
};

module.exports.handler = async (event, context) => {
	if (event.path === "/send") {
		const {target, message} = event.queryStringParameters;
		await sns.publish({
			TopicArn: process.env.TOPIC_ARN,
			Message: message,
			MessageAttributes: {
				target: {
					DataType: "String",
					StringValue: target,
				}
			}
		}).promise();

		return {
			statusCode: 200,
			headers: {
				"Access-Control-Allow-Origin": "*",
			},
			body: "OK",
		};
	}else {
		const res = await getPaginatedResults(async (LastEvaluatedKey) => {
			const res = await ddb.scan({ExclusiveStartKey: LastEvaluatedKey, TableName: process.env.TABLE_NAME}).promise();
			return {
				marker: res.LastEvaluatedKey,
				results: res.Items,
			};
		});

		return {
			statusCode: 200,
			headers: {
				"Access-Control-Allow-Origin": "*",
				"Content-Type": "application/json",
			},
			body: JSON.stringify(res),
		};
	}
};
