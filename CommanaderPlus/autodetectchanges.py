import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import os

class MyHandler(FileSystemEventHandler):
    def on_modified(self, event):
        print(f"File {event.src_path} has been modified")

    def on_created(self, event):
        print(f"File {event.src_path} has been created")

    def on_deleted(self, event):
        print(f"File {event.src_path} has been deleted")

if __name__ == "__main__":
    event_handler = MyHandler()
    observer = Observer()

    paths = ["/usr/local/bin", os.path.expanduser("~/bin")]
    for path in paths:
        observer.schedule(event_handler, path, recursive=False)

    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

