from uuid import UUID
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.ext.asyncio import AsyncSession
import logging

from app.websockets.manager import manager

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/ws", tags=["WebSockets"])


@router.websocket("/{user_id}")
async def websocket_endpoint(
    websocket: WebSocket, 
    user_id: UUID,
    # In a real app we'd validate the WS token:
    # current_user = Depends(get_current_user_ws)
):
    """
    WebSocket endpoint for real-time updates.
    Clients connect to ws://{host}/api/v1/ws/{user_id}
    """
    await manager.connect(websocket, user_id)
    try:
        while True:
            # We don't expect the client to send much data, but we need to keep the connection open
            # and listen for disconnects. We can also handle ping/pong if needed.
            data = await websocket.receive_text()
            logger.info(f"Received message from WS user {user_id}: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
        logger.info(f"WebSocket user {user_id} disconnected")
