import {connect} from "mqtt";
import readline from "readline";

const {IOT_ENDPOINT, CA, CERT, KEY, THING_NAME} = process.env;
const opt = {
	host: IOT_ENDPOINT,
	protocol: "mqtt",
	clientId: THING_NAME,
	clean: true,
	key: KEY,
	cert: CERT,
	ca: CA,
	reconnectPeriod: 0,
};

const client  = connect(opt);

client.on("error", (e) => {
	console.log(e);
	process.exit(-1);
});
const rl = readline.createInterface({
	input: process.stdin,
});

client.on("connect", () => {
	client.subscribe(`$aws/things/${THING_NAME}/shadow/name/test/update/documents`, (err) => {
		if (!err) {
			console.log("Connected, send some messages by typing in the terminal (press enter to send)");
			rl.on("line", (data) => {
				client.publish(`$aws/things/${THING_NAME}/shadow/name/test/update`, JSON.stringify({state: {reported: {value: data}}}));
			});
		}
	});
});

client.on("message", (topic, message) => {
	console.log("[Message received]: " + JSON.stringify(JSON.parse(message.toString()).current.state, undefined, 2));
});
