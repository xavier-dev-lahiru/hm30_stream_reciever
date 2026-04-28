#ifndef VIDEO_STREAM_ITEM_H
#define VIDEO_STREAM_ITEM_H

#include <QQuickPaintedItem>
#include <QImage>
#include <QPainter>
#include <mutex>

class RosBackend;

class VideoStreamItem : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(QObject* targetBackend READ targetBackend WRITE setTargetBackend NOTIFY targetBackendChanged)
public:
    explicit VideoStreamItem(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    QObject* targetBackend() const;
    void setTargetBackend(QObject* backend);

public slots:
    void updateImage(const QImage &image);

private:
    QImage m_currentImage;
    std::mutex m_mutex;
    RosBackend* m_backend = nullptr;

signals:
    void targetBackendChanged();
};

#endif // VIDEO_STREAM_ITEM_H
