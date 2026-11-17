from fastapi import WebSocket
from typing import Dict, List

class ConnectionManager:
    def __init__(self):
        # Maps exam_id to a list of active WebSockets (teachers viewing that exam)
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, exam_id: str):
        await websocket.accept()
        if exam_id not in self.active_connections:
            self.active_connections[exam_id] = []
        self.active_connections[exam_id].append(websocket)

    def disconnect(self, websocket: WebSocket, exam_id: str):
        if exam_id in self.active_connections:
            self.active_connections[exam_id].remove(websocket)
            if not self.active_connections[exam_id]:
                del self.active_connections[exam_id]

    async def broadcast(self, exam_id: str, message: dict):
        if exam_id in self.active_connections:
            for connection in self.active_connections[exam_id]:
                await connection.send_json(message)

manager = ConnectionManager()