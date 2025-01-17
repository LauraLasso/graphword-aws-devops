import os
import json
from collections import Counter

class StatBuilder:
    def __init__(self, datalake_directory="datalake", datamart_directory="datamart_stats"):
        self.datalake_directory = datalake_directory
        self.datamart_directory = datamart_directory

    def gather_statistics(self):
        stats = {
            "total_files": 0,
            "word_count": Counter(),
            "average_file_size": 0,
            "largest_file": {"name": None, "size": 0}
        }
        total_size = 0

        for date_dir in os.listdir(self.datalake_directory):
            date_path = os.path.join(self.datalake_directory, date_dir)
            if os.path.isdir(date_path):
                for book_dir in os.listdir(date_path):
                    file_path = os.path.join(date_path, book_dir, f"normalized_{book_dir}.txt")
                    if os.path.exists(file_path):
                        stats["total_files"] += 1

                        # Calculate file size
                        file_size = os.path.getsize(file_path)
                        total_size += file_size
                        if file_size > stats["largest_file"]["size"]:
                            stats["largest_file"]["name"] = file_path
                            stats["largest_file"]["size"] = file_size

                        # Count words
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read().split()
                            stats["word_count"].update(content)

        if stats["total_files"] > 0:
            stats["average_file_size"] = total_size / stats["total_files"]

        return stats

    def save_statistics(self, stats):
        os.makedirs(self.datamart_directory, exist_ok=True)
        stats_file = os.path.join(self.datamart_directory, "statistics.json")
        with open(stats_file, 'w', encoding='utf-8') as f:
            json.dump(stats, f, ensure_ascii=False, indent=4)
        print(f"Statistics saved in: {stats_file}")

    def run(self):
        stats = self.gather_statistics()
        self.save_statistics(stats)


if __name__ == "__main__":
    builder = StatBuilder()
    builder.run()
