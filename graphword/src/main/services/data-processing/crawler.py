import os
import requests
import time
from datetime import datetime
from threading import Timer
import re
from collections import defaultdict

class GutenbergFileReader:
    
    def download_file(self, file_url):
        response = requests.get(file_url, stream=True)
        if response.status_code == 200:
            file_name = file_url.split('/')[-1][2:]
            book_directory = file_name[:-4]
            download_path = GuttenbergDatalakeCreator().set_file_path(book_directory, datetime.now())
            full_path = os.path.join(download_path, file_name)

            with open(full_path, 'wb') as output_file:
                for chunk in response.iter_content(chunk_size=16384):
                    if chunk:
                        output_file.write(chunk)
            print(f"Downloaded: {full_path}")
        else:
            print(f"Failed to download: {file_url}")

    def read(self, book_id):
        path = self.get_file_path(book_id)
        if os.path.exists(path):
            with open(path, 'r') as file:
                content = file.read()
            return content
        else:
            raise FileNotFoundError(f"File not found: {path}")

    def get_file_path(self, book_id):
        base_directory = "datalake"
        for date_dir in os.listdir(base_directory):
            book_file = os.path.join(base_directory, date_dir, f"{book_id}/{book_id}.txt")
            if os.path.exists(book_file):
                return book_file
        return "File not found"


class GuttenbergDatalakeCreator:
    
    def set_file_path(self, filename, current_date):
        date_str = current_date.strftime("%Y%m%d")
        folder_path = os.path.join("datalake", date_str, filename)
        os.makedirs(folder_path, exist_ok=True)
        return folder_path

    def create_date_folder(self, current_date):
        date_str = current_date.strftime("%Y%m%d")
        folder_path = os.path.join("datalake", date_str)
        os.makedirs(folder_path, exist_ok=True)


class BatchDownloader:
    
    def __init__(self, batch_size, gutenberg_file_reader, book_ids):
        self.batch_size = batch_size
        self.gutenberg_file_reader = gutenberg_file_reader
        self.book_ids = book_ids

    def download(self):
        count = 0
        self.set_books_batch(0)

        while count == 0:
            for i in range(self.batch_size):
                try:
                    self.gutenberg_file_reader.download_file(self.book_ids[i])
                    count += 1
                except Exception as e:
                    print(f"Error downloading file: {self.book_ids[i]} - {e}")

            if count == 0:
                self.set_books_batch(10)

    def set_books_batch(self, mod):
        start = self.get_last_book_id("datalake")
        for i in range(start + 1 + mod, start + 1 + mod + self.batch_size):
            self.book_ids[i - (start + 1 + mod)] = self.url_setter(i)

    def get_last_book_id(self, base_directory):
        last_book_id = 0
        for date_dir in os.listdir(base_directory):
            date_dir_path = os.path.join(base_directory, date_dir)
            if os.path.isdir(date_dir_path):
                for book_dir in os.listdir(date_dir_path):
                    try:
                        book_id = int(book_dir)
                        last_book_id = max(last_book_id, book_id)
                    except ValueError:
                        continue
        return last_book_id

    def url_setter(self, book_id):
        return f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt"


class NormalizedGutenbergFileReader(GutenbergFileReader):
    # Lista básica de stopwords
    STOPWORDS = {"el", "la", "los", "las", "y", "o", "de", "a", "en", "un", "una"}

    # Método para normalizar el texto, convertir a minúsculas y quitar caracteres no alfabéticos
    def normalize_text(self, text):
        normalized = re.sub(r'[^a-záéíóúñ ]', ' ', text.lower())
        normalized = re.sub(r'\s+', ' ', normalized).strip()
        return normalized

    # Método para eliminar stopwords
    def remove_stopwords(self, text):
        words = text.split()
        filtered_text = ' '.join([word for word in words if word not in self.STOPWORDS])
        return filtered_text

    # Método para procesar y guardar archivos normalizados en el directorio datalake
    def process_all_files(self):
        base_directory = "datalake"
        
        for date_dir in os.listdir(base_directory):
            date_path = os.path.join(base_directory, date_dir)
            if os.path.isdir(date_path):
                for book_dir in os.listdir(date_path):
                    book_path = os.path.join(date_path, book_dir, f"{book_dir}.txt")
                    
                    normalized_file = os.path.join(date_path, book_dir, f"normalized_{book_dir}.txt")
                    if os.path.exists(normalized_file):
                        continue
                    if os.path.exists(book_path):
                        self.process_and_save_normalized_file(book_dir, book_path)

    # Método para normalizar y guardar el archivo
    def process_and_save_normalized_file(self, book_id, original_path):
        if not os.path.exists(original_path):
            raise FileNotFoundError(f"File not found: {original_path}")

        # Leer el contenido del archivo original
        with open(original_path, 'r', encoding='utf-8') as file:
            content = file.read()

        # Normalizar el texto y eliminar las stopwords
        normalized_text = self.normalize_text(content)
        cleaned_text = self.remove_stopwords(normalized_text)

        # Guardar el archivo normalizado y sin stopwords
        new_file_name = f"normalized_{book_id}.txt"
        new_file_path = os.path.join(os.path.dirname(original_path), new_file_name)

        with open(new_file_path, 'w', encoding='utf-8') as new_file:
            new_file.write(cleaned_text)

        print(f"Archivo procesado guardado en: {new_file_path}")

# class VocabularyProcessor:
#     def __init__(self):
#         self.global_vocabulary = defaultdict(int)

#     def process_document_vocabulary(self, normalized_text):
#         word_count = defaultdict(int)
#         words = normalized_text.split()

#         for word in words:
#             word_count[word] += 1
#             self.global_vocabulary[word] += 1

#         return word_count

#     def save_vocabulary_to_file(self, vocabulary, file_path):
#         with open(file_path, 'w', encoding='utf-8') as vocab_file:
#             for word, count in vocabulary.items():
#                 vocab_file.write(f"{word}: {count}\n")

#     #def save_global_vocabulary(self, file_path="global_vocabulary.txt"):
#     #    with open(file_path, 'w', encoding='utf-8') as vocab_file:
#     #        for word, count in self.global_vocabulary.items():
#     #            vocab_file.write(f"{word}: {count}\n")

#     def save_global_vocabulary(self, base_directory="datalake"):
#         # Obtener la fecha actual en el formato YYYYMMDD
#         #current_date = datetime.now().strftime("%Y%m%d")
#         # Crear la ruta dentro del datalake para guardar el vocabulario global
#         global_vocab_path = os.path.join(base_directory, "global_vocabulary.txt")
#         os.makedirs(os.path.dirname(global_vocab_path), exist_ok=True)

#         # Guardar el vocabulario global en el archivo
#         with open(global_vocab_path, 'w', encoding='utf-8') as vocab_file:
#             for word, count in self.global_vocabulary.items():
#                 vocab_file.write(f"{word}: {count}\n")
#         print(f"Vocabulario global guardado en: {global_vocab_path}")


class Controller:
    def __init__(self, batch_size, total_books):
        self.gutenberg_file_reader = NormalizedGutenbergFileReader()  # Cambiado a NormalizedGutenbergFileReader
        self.batch_size = batch_size
        self.total_books = total_books
        self.ids = [None] * batch_size
        self.batch_downloader = BatchDownloader(batch_size, self.gutenberg_file_reader, self.ids)
        self.guttenberg_datalake_creator = GuttenbergDatalakeCreator()

    def execute(self):
        current = datetime.now()
        self.guttenberg_datalake_creator.create_date_folder(current)
        time.sleep(1)
        self.batch_downloader.download()

        # Llamar al método para procesar todos los archivos después de la descarga
        self.gutenberg_file_reader.process_all_files()

    def run(self):
        books_downloaded = 0
        while books_downloaded < self.total_books:
            print(f"Descargando lote de {self.batch_size} libros...")
            self.execute()
            books_downloaded += self.batch_size
            print(f"Total de libros descargados: {books_downloaded}/{self.total_books}")

            if books_downloaded < self.total_books:
                print("Esperando 5 minutos para el próximo lote...")
                time.sleep(300)  # Esperar 2 minutos
        print("Descarga completa: se han descargado todos los libros.")

# Ejemplo de uso:
if __name__ == "__main__":
    controller = Controller(batch_size=5, total_books=10)  # Descargar en lotes de 5 hasta 30 libros
    controller.run()