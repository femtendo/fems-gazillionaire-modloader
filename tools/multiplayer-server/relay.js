#!/usr/bin/env node
// Multiplayer relay server. Dumb pipe: holds one GameType ByteArray blob
// per room and forwards it to whichever client's turn is next. Does not
// parse or validate game state — see docs/multiplayer-architecture.md.
//
// Wire format per frame, over a plain TCP socket:
//   [1 byte type][4 bytes big-endian length][payload]
// type 0x01 = JSON control message (UTF-8 payload)
// type 0x02 = state blob (raw GameType.serialize() bytes)
//
// Usage: node relay.js [port]

'use strict';

const net = require('net');

const FRAME_JSON = 0x01;
const FRAME_STATE = 0x02;
const HEADER_LEN = 5;
const ROOM_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I

function makeRoomCode() {
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += ROOM_CODE_CHARS[Math.floor(Math.random() * ROOM_CODE_CHARS.length)];
    }
    return code;
}

function writeFrame(socket, type, payload) {
    const header = Buffer.alloc(HEADER_LEN);
    header.writeUInt8(type, 0);
    header.writeUInt32BE(payload.length, 1);
    socket.write(Buffer.concat([header, payload]));
}

function sendJson(socket, obj) {
    writeFrame(socket, FRAME_JSON, Buffer.from(JSON.stringify(obj), 'utf8'));
}

// Splits a stream of frames out of a growing buffer. Calls onFrame(type, payload)
// for each complete frame and returns the leftover unconsumed buffer.
function drainFrames(buffer, onFrame) {
    let offset = 0;
    while (buffer.length - offset >= HEADER_LEN) {
        const type = buffer.readUInt8(offset);
        const len = buffer.readUInt32BE(offset + 1);
        if (buffer.length - offset < HEADER_LEN + len) break;
        onFrame(type, buffer.subarray(offset + HEADER_LEN, offset + HEADER_LEN + len));
        offset += HEADER_LEN + len;
    }
    return buffer.subarray(offset);
}

class Room {
    constructor(code) {
        this.code = code;
        this.clients = new Map(); // slot (int) -> socket
        this.turnSlot = 0;
    }

    broadcastPeerList() {
        const slots = [...this.clients.keys()];
        for (const socket of this.clients.values()) {
            sendJson(socket, { type: 'peer-list', slots, turnSlot: this.turnSlot });
        }
    }
}

function startServer(port) {
    const rooms = new Map(); // code -> Room

    const server = net.createServer((socket) => {
        let buffer = Buffer.alloc(0);
        let room = null;
        let mySlot = null;

        socket.on('data', (chunk) => {
            buffer = Buffer.concat([buffer, chunk]);
            buffer = drainFrames(buffer, (type, payload) => {
                if (type === FRAME_JSON) {
                    handleControl(JSON.parse(payload.toString('utf8')));
                } else if (type === FRAME_STATE) {
                    handleState(payload);
                }
            });
        });

        function handleControl(msg) {
            if (msg.type === 'create') {
                let code;
                do { code = makeRoomCode(); } while (rooms.has(code));
                room = new Room(code);
                rooms.set(code, room);
                mySlot = msg.slot || 0;
                room.clients.set(mySlot, socket);
                sendJson(socket, { type: 'created', code });
                room.broadcastPeerList();
            } else if (msg.type === 'join') {
                room = rooms.get(msg.code);
                if (!room) {
                    sendJson(socket, { type: 'error', message: 'no such room' });
                    return;
                }
                mySlot = msg.slot;
                room.clients.set(mySlot, socket);
                sendJson(socket, { type: 'joined', code: room.code });
                room.broadcastPeerList();
            } else if (msg.type === 'chat' && room) {
                for (const [slot, peer] of room.clients) {
                    if (slot !== mySlot) sendJson(peer, { type: 'chat', from: mySlot, text: msg.text });
                }
            }
        }

        function handleState(payload) {
            if (!room) return;
            // Advance whose turn the server thinks it is; the client is the
            // source of truth for game rules, the server just relays.
            room.turnSlot = typeof room.nextTurnSlot === 'number' ? room.nextTurnSlot : room.turnSlot;
            for (const [slot, peer] of room.clients) {
                if (slot !== mySlot) writeFrame(peer, FRAME_STATE, payload);
            }
        }

        socket.on('close', () => {
            if (room && mySlot !== null) {
                room.clients.delete(mySlot);
                if (room.clients.size === 0) rooms.delete(room.code);
                else room.broadcastPeerList();
            }
        });

        socket.on('error', () => {});
    });

    server.listen(port, () => {
        console.log(`multiplayer relay listening on port ${port}`);
    });

    return server;
}

if (require.main === module) {
    const port = parseInt(process.argv[2], 10) || 8642;
    startServer(port);
}

module.exports = { startServer, FRAME_JSON, FRAME_STATE, HEADER_LEN, drainFrames, writeFrame };
