import os
import re
from collections import defaultdict


class VocabularyProcessor:
    def __init__(self):
        self.global_vocabulary = defaultdict(int)

    def process_document_vocabulary(self, normalized_text):
        word_count = defaultdict(int)
        words = normalized_text.split()

        for word in words:
            word_count[word] += 1
            self.global_vocabulary[word] += 1

        return word_count

    def save_vocabulary_to_file(self, vocabulary, file_path):
        with open(file_path, 'w', encoding='utf-8') as vocab_file:
            for word, count in vocabulary.items():
                vocab_file.write(f"{word}: {count}\n")

    def save_global_vocabulary(self, base_directory="datamart_dictionary"):
        global_vocab_path = os.path.join(base_directory, "global_vocabulary.txt")
        os.makedirs(os.path.dirname(global_vocab_path), exist_ok=True)

        with open(global_vocab_path, 'w', encoding='utf-8') as vocab_file:
            for word, count in self.global_vocabulary.items():
                vocab_file.write(f"{word}: {count}\n")
        print(f"Global vocabulary saved in: {global_vocab_path}")


class DatalakeReader:
    def __init__(self, base_directory="datalake"):
        self.base_directory = base_directory

    def get_normalized_files(self):
        normalized_files = []
        for date_dir in os.listdir(self.base_directory):
            date_path = os.path.join(self.base_directory, date_dir)
            if os.path.isdir(date_path):
                for book_dir in os.listdir(date_path):
                    normalized_file = os.path.join(date_path, book_dir, f"normalized_{book_dir}.txt")
                    if os.path.exists(normalized_file):
                        normalized_files.append(normalized_file)
        return normalized_files

    def read_file(self, file_path):
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as file:
                return file.read()
        else:
            raise FileNotFoundError(f"File not found: {file_path}")


class DatamartWriter:
    def __init__(self, base_directory="datamart_dictionary"):
        self.base_directory = base_directory

    def save_document_vocabulary(self, vocabulary, date_dir, book_dir):
        dir_path = os.path.join(self.base_directory, date_dir, book_dir)
        os.makedirs(dir_path, exist_ok=True)
        vocab_file_path = os.path.join(dir_path, f"vocab_{book_dir}.txt")
        with open(vocab_file_path, 'w', encoding='utf-8') as vocab_file:
            for word, count in vocabulary.items():
                vocab_file.write(f"{word}: {count}\n")
        print(f"Vocabulary saved for book {book_dir} in: {vocab_file_path}")

    def save_global_vocabulary(self, vocabulary):
        global_vocab_path = os.path.join(self.base_directory, "global_vocabulary.txt")
        os.makedirs(os.path.dirname(global_vocab_path), exist_ok=True)
        with open(global_vocab_path, 'w', encoding='utf-8') as vocab_file:
            for word, count in vocabulary.items():
                vocab_file.write(f"{word}: {count}\n")
        print(f"Global vocabulary saved in: {global_vocab_path}")


class Controller:
    def __init__(self, datalake_directory="datalake", datamart_directory="datamart_dictionary"):
        self.datalake_reader = DatalakeReader(datalake_directory)
        self.datamart_writer = DatamartWriter(datamart_directory)
        self.vocabulary_processor = VocabularyProcessor()

    def process_datalake_to_datamart(self):
        # Leer archivos normalizados desde el datalake
        normalized_files = self.datalake_reader.get_normalized_files()

        # Procesar cada archivo normalizado
        for file_path in normalized_files:
            try:
                # Leer contenido del archivo normalizado
                content = self.datalake_reader.read_file(file_path)

                # Generar vocabulario del documento
                doc_vocabulary = self.vocabulary_processor.process_document_vocabulary(content)

                # Extraer información de la ruta del archivo
                path_parts = file_path.split(os.sep)
                date_dir = path_parts[-3]  # Fecha del directorio
                book_dir = path_parts[-2]  # ID del libro

                # Guardar vocabulario del documento en el datamart
                self.datamart_writer.save_document_vocabulary(doc_vocabulary, date_dir, book_dir)
            except Exception as e:
                print(f"Error processing file {file_path}: {e}")

        # Guardar vocabulario global en el datamart
        self.datamart_writer.save_global_vocabulary(self.vocabulary_processor.global_vocabulary)


# Main Script
if __name__ == "__main__":
    controller = Controller()
    controller.process_datalake_to_datamart()