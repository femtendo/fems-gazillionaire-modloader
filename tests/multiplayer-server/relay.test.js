#!/usr/bin/env node
// Self-check for tools/multiplayer-server/relay.js.
// Run directly: node tests/multiplayer-server/relay.test.js
const assert = require('assert');
const net = require('net');
const { startServer, FRAME_JSON, FRAME_STATE, HEADER_LEN, drainFrames, writeFrame } = require('../../tools/multiplayer-server/relay');

// Frame round-trip: a buffer split across two chunks still drains cleanly.
{
    const frames = [];
    let buf = Buffer.alloc(0);
    const payload = Buffer.from('hello');
    const header = Buffer.alloc(HEADER_LEN);
    header.writeUInt8(FRAME_JSON, 0);
    header.writeUInt32BE(payload.length, 1);
    const full = Buffer.concat([header, payload]);

    buf = drainFrames(Buffer.concat([buf, full.subarray(0, 3)]), (t, p) => frames.push([t, p]));
    assert.strictEqual(frames.length, 0, 'partial frame must not fire yet');
    buf = drainFrames(Buffer.concat([buf, full.subarray(3)]), (t, p) => frames.push([t, p]));
    assert.strictEqual(frames.length, 1);
    assert.strictEqual(frames[0][0], FRAME_JSON);
    assert.strictEqual(frames[0][1].toString('utf8'), 'hello');
}

// End-to-end: two clients create/join a room and relay a state blob.
async function endToEnd() {
    const server = startServer(0);
    await new Promise((resolve) => server.once('listening', resolve));
    const port = server.address().port;

    // Wraps a socket with a FIFO queue of decoded frames so no frame is
    // ever dropped just because two arrived in the same TCP chunk.
    function connect() {
        return new Promise((resolve) => {
            const socket = net.createConnection(port, '127.0.0.1', () => {
                const queue = [];
                const waiters = [];
                let buf = Buffer.alloc(0);
                socket.on('data', (chunk) => {
                    buf = Buffer.concat([buf, chunk]);
                    buf = drainFrames(buf, (type, payload) => {
                        const frame = { type, payload };
                        const waiter = waiters.shift();
                        if (waiter) waiter(frame);
                        else queue.push(frame);
                    });
                });
                socket.nextFrame = () => new Promise((res) => {
                    const frame = queue.shift();
                    if (frame) res(frame);
                    else waiters.push(res);
                });
                socket.nextJson = async () => {
                    const frame = await socket.nextFrame();
                    assert.strictEqual(frame.type, FRAME_JSON);
                    return JSON.parse(frame.payload.toString('utf8'));
                };
                resolve(socket);
            });
        });
    }

    function sendJson(socket, obj) {
        writeFrame(socket, FRAME_JSON, Buffer.from(JSON.stringify(obj), 'utf8'));
    }

    const host = await connect();
    sendJson(host, { type: 'create', slot: 0 });
    const created = await host.nextJson();
    assert.strictEqual(created.type, 'created');
    assert.strictEqual(created.code.length, 6);
    await host.nextJson(); // peer-list after create

    const guest = await connect();
    sendJson(guest, { type: 'join', code: created.code, slot: 1 });
    const joined = await guest.nextJson();
    assert.strictEqual(joined.type, 'joined');
    await guest.nextJson(); // peer-list from own join

    const guestPeerList = await host.nextJson(); // host sees updated peer-list
    assert.deepStrictEqual(guestPeerList.slots.sort(), [0, 1]);

    // Host publishes a fake state blob; guest should receive it verbatim.
    const fakeState = Buffer.from([1, 2, 3, 4, 5]);
    writeFrame(host, FRAME_STATE, fakeState);
    const stateFrame = await guest.nextFrame();
    assert.strictEqual(stateFrame.type, FRAME_STATE);
    assert.deepStrictEqual(stateFrame.payload, fakeState);

    host.destroy();
    guest.destroy();
    server.close();
}

endToEnd().then(() => {
    console.log('relay.test.js: all assertions passed');
}).catch((err) => {
    console.error(err);
    process.exit(1);
});
