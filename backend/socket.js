const socketIo = require("socket.io");

let io;

module.exports = {

  init: (server) => {

    io = socketIo(server, {
      cors: {
        origin: "*",
      },
    });

    io.on("connection", (socket) => {

      console.log("Socket Connected");

      socket.on("joinChefRoom", (chefId) => {

        socket.join(chefId);

        console.log("Chef joined room:", chefId);

      });

      socket.on("disconnect", () => {

        console.log("Disconnected");

      });

    });

    return io;

  },

  getIO: () => {

    if (!io) {
      throw new Error("Socket.io not initialized");
    }

    return io;

  },

};