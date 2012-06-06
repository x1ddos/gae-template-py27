// Compile with: javac -cp ~/src/closure/compiler/build/compiler.jar MsgExtractor.java
//
// And then run with:
// 1. make js OUTPUT_MODE=list > /tmp/files.txt
// 2. for i in `cat /tmp/files.txt`; do java -cp ~/src/closure/compiler/build/compiler.jar:. MsgExtractor notepad $i; done > trans.xtb
// 3. translate trans.xtb into trans-it.xtb
// 4. make js FLAGS="--formatting PRETTY_PRINT --translations_file trans-it.xtb --translations_project notepad --define=goog.LOCALE='it'"
// - Don't forget to wrap the output in <translationbundle> tag.
//
// The above 1-2 is run on make js_extract_msg
//
// Example of XTB from cromium:
// http://code.google.com/p/grit-i18n/source/browse/trunk/grit/testdata/generated_resources_fr.xtb
//
// Also, see http://cldr.unicode.org/development/development-process/design-proposals/xmb
//
// <?xml version="1.0" ?>
// <!DOCTYPE translationbundle>
// <translationbundle lang="fr">
// <translation id="6779164083355903755">Supprime&amp;r</translation>
// <translation id="6879617193011158416">Activer la barre de favoris</translation>
// <translation id="8130276680150879341">Déconnexion du réseau privé</translation>
// <translation id="5463582782056205887">Essayez d'ajouter
//         <ph name="PRODUCT_NAME"/>
//         aux programmes autorisés dans les paramètres de votre pare-feu ou de votre antivirus. S'il
//         est déjà autorisé, tentez de le supprimer de la liste et de l'ajouter à nouveau à
//         la liste des programmes autorisés.</translation>
// </translationbundle>

import java.util.Collection;
import java.lang.StringBuilder;
import java.io.IOException;

import com.google.javascript.jscomp.SourceFile;
import com.google.javascript.jscomp.JsMessage;
import com.google.javascript.jscomp.JsMessageExtractor;
import com.google.javascript.jscomp.GoogleJsMessageIdGenerator;

// args[0]: project name
// args[1]: file name

public class MsgExtractor {
  public static final String TRANSLATION_START_TAG = "<translation id=\"%s\">";
  public static final String TRANSLATION_END_TAG   = "</translation>";
  public static final String PH_TAG                = "<ph name=\"%s\"/>";

  public static void main(String[] args) throws IOException 
  {
    JsMessageExtractor extractor = 
      new JsMessageExtractor(new GoogleJsMessageIdGenerator(args[0]), JsMessage.Style.CLOSURE);

    Collection<JsMessage> messages = 
      extractor.extractMessages(SourceFile.fromFile(args[1]));

    StringBuilder sb = new StringBuilder();
    for (JsMessage message : messages) {
      sb.append(String.format(TRANSLATION_START_TAG, message.getId()));
      for (CharSequence p : message.parts()) {
        if (p instanceof JsMessage.PlaceholderReference) {
          JsMessage.PlaceholderReference ph = (JsMessage.PlaceholderReference) p;
          sb.append(String.format(PH_TAG, ph.getName().toUpperCase()));
        } else {
          sb.append(p.toString());
        }
      }
      sb.append(TRANSLATION_END_TAG);

      System.out.println(sb.toString());
    }
  }
}
