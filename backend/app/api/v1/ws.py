from uuid import UUID
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.ext.asyncio import AsyncSession
import logging
import json

from app.websockets.manager import manager
from app.core.security import decode_access_token

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/ws", tags=["WebSockets"])


@router.websocket("/{user_id}")
async def websocket_endpoint(
    websocket: WebSocket, 
    user_id: UUID,
    token: str = Query(None)
):
    """
    WebSocket endpoint for real-time updates.
    Clients connect to ws://{host}/api/v1/ws/{user_id}?token=...
    """
    if not token:
        await websocket.close(code=1008, reason="Missing token")
        return
        
    try:
        payload = decode_access_token(token)
        token_sub = payload.get("sub")
        if not token_sub or str(user_id) != token_sub:
            await websocket.close(code=1008, reason="Invalid user token")
            return
    except Exception:
        await websocket.close(code=1008, reason="Invalid token")
        return

    await manager.connect(websocket, user_id)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                message = json.loads(data)
            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "message": "Invalid JSON"})
                continue
            if message.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
                continue
            logger.info(f"Received message from WS user {user_id}: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
        logger.info(f"WebSocket user {user_id} disconnected")
