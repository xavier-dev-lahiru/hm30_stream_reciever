#include "VideoStreamItem.h"
#include "RosBackend.h"

VideoStreamItem::VideoStreamItem(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    // Important: by default QQuickPaintedItem does not have a size, and won't paint
    // unless you give it width/height in QML and set this flag (true by default usually).
}

QObject* VideoStreamItem::targetBackend() const
{
    return m_backend;
}

void VideoStreamItem::setTargetBackend(QObject* backendObj)
{
    RosBackend* backend = qobject_cast<RosBackend*>(backendObj);
    
    if (m_backend == backend)
        return;

    if (m_backend) {
        disconnect(m_backend, &RosBackend::newFrameReceived, this, &VideoStreamItem::updateImage);
    }

    m_backend = backend;

    if (m_backend) {
        connect(m_backend, &RosBackend::newFrameReceived, this, &VideoStreamItem::updateImage);
    }

    emit targetBackendChanged();
}

void VideoStreamItem::paint(QPainter *painter)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    if (!m_currentImage.isNull()) {
        // Draw the image scaled to fill the item's bounding rect
        painter->drawImage(boundingRect(), m_currentImage);
    } else {
        // Fallback drawing if no image
        painter->fillRect(boundingRect(), QColor(8, 8, 8)); // Dark background
    }
}

void VideoStreamItem::updateImage(const QImage &image)
{
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        // We clone to avoid the image data being destroyed/modified while painting
        m_currentImage = image.copy();
    }
    // Schedule a repaint on the UI thread
    QMetaObject::invokeMethod(this, "update", Qt::QueuedConnection);
}
