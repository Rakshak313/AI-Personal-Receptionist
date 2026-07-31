from flask import Flask, render_template
from database import get_calls

app = Flask(__name__)


@app.route("/")
def index():
    calls = get_calls()
    return render_template("index.html", calls=calls)


if __name__ == "__main__":
    app.run(debug=True)