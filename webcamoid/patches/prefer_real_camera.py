from pathlib import Path
import sys

root = Path(sys.argv[1])
capture_path = root / "libAvKys/Plugins/VideoCapture/src/capture/v4l2sys/src/capturev4l2.cpp"
text = capture_path.read_text()
old_description = '''        if (x_ioctl(fd, VIDIOC_QUERYCAP, &capability) >= 0)
            description = reinterpret_cast<const char *>(capability.card);

        qInfo() << "Detected camera:" << description << "(" << fileName << ")";'''
new_description = '''        if (x_ioctl(fd, VIDIOC_QUERYCAP, &capability) >= 0)
            description = reinterpret_cast<const char *>(capability.card);

        auto normalizedDescription = description.toLower();
        auto driver = QString(reinterpret_cast<const char *>(capability.driver)).toLower();
        if (normalizedDescription.contains("dummy")
            || normalizedDescription.contains("loopback")
            || driver.contains("v4l2loopback")) {
            qInfo() << "Skipping virtual or dummy camera:" << description
                    << "(" << fileName << ")";
            x_close(fd);
            continue;
        }

        qInfo() << "Detected camera:" << description << "(" << fileName << ")";'''
if old_description not in text:
    raise SystemExit("capturev4l2.cpp 中找不到摄像头枚举位置")
text = text.replace(old_description, new_description, 1)
old_set_device = '''void CaptureV4L2::setDevice(const QString &device)
{
    if (this->d->m_device == device)
        return;'''
new_set_device = '''void CaptureV4L2::setDevice(const QString &device)
{
    if (!device.isEmpty()
        && !this->d->m_devices.contains(device)
        && !this->d->m_devices.isEmpty()) {
        this->setDevice(this->d->m_devices.first());
        return;
    }

    if (this->d->m_device == device)
        return;'''
if old_set_device not in text:
    raise SystemExit("capturev4l2.cpp 中找不到设备选择位置")
capture_path.write_text(text.replace(old_set_device, new_set_device, 1))
