import type { Server as SocketServer } from "socket.io";

let io: SocketServer | null = null;

export function setSocketServer(server: SocketServer) {
  io = server;
}

export function getSocketServer(): SocketServer | null {
  return io;
}
