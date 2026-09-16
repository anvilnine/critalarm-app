package app.critalarm.notifications

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF

/**
 * The five faces, drawn for a notification large icon.
 *
 * A port of draw(in:size:) in ios/CritAlarmActivity/FaceView.swift. Every
 * ratio below is the same number that file uses, so the two platforms draw the
 * same character. Change one and change the other.
 */
object FaceBitmap {
    fun render(face: CritAlarmFace, sizePx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val size = sizePx.toFloat()

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = face.canvasColor
        }
        val corner = size * 0.3f
        canvas.drawRoundRect(RectF(0f, 0f, size, size), corner, corner, fill)

        val outline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = CritAlarmPalette.INK
            strokeWidth = maxOf(1.5f, size * 0.05f)
        }
        val inset = outline.strokeWidth / 2f
        canvas.drawRoundRect(
            RectF(inset, inset, size - inset, size - inset),
            corner, corner, outline,
        )

        val pad = size * 0.16f
        canvas.save()
        canvas.translate(pad, pad)
        drawFeatures(canvas, face, size - pad * 2f)
        canvas.restore()
        return bitmap
    }

    private fun drawFeatures(canvas: Canvas, face: CritAlarmFace, box: Float) {
        val w = box
        val h = box
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = face.strokeColor
            strokeWidth = maxOf(2f, w * 0.09f)
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val solid = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = face.strokeColor
        }

        val eyeY = h * 0.36f
        val leftX = w * 0.28f
        val rightX = w * 0.72f

        when (face) {
            CritAlarmFace.ACKED -> for (x in listOf(leftX, rightX)) {
                val path = Path()
                path.moveTo(x - w * 0.12f, eyeY)
                path.quadTo(x, eyeY - h * 0.14f, x + w * 0.12f, eyeY)
                canvas.drawPath(path, stroke)
            }
            CritAlarmFace.ALARMED -> for (x in listOf(leftX, rightX)) {
                canvas.drawCircle(x, eyeY, w * 0.13f, stroke)
            }
            else -> for (x in listOf(leftX, rightX)) {
                canvas.drawCircle(x, eyeY, w * 0.085f, solid)
            }
        }

        if (face == CritAlarmFace.WORRIED || face == CritAlarmFace.ALARMED) {
            val lift = if (face == CritAlarmFace.ALARMED) h * 0.10f else h * 0.07f
            for ((x, inward) in listOf(leftX to 1f, rightX to -1f)) {
                canvas.drawLine(
                    x - w * 0.13f * inward, eyeY - h * 0.22f,
                    x + w * 0.13f * inward, eyeY - h * 0.22f + lift,
                    stroke,
                )
            }
        }

        val mouthY = h * 0.72f
        when (face) {
            CritAlarmFace.ALARMED -> canvas.drawOval(
                RectF(w * 0.34f, mouthY - h * 0.10f, w * 0.66f, mouthY + h * 0.12f),
                solid,
            )
            CritAlarmFace.WORRIED -> {
                val path = Path()
                path.moveTo(w * 0.32f, mouthY + h * 0.04f)
                path.cubicTo(
                    w * 0.44f, mouthY - h * 0.08f,
                    w * 0.56f, mouthY + h * 0.12f,
                    w * 0.68f, mouthY + h * 0.04f,
                )
                canvas.drawPath(path, stroke)
            }
            else -> {
                val path = Path()
                path.moveTo(w * 0.34f, mouthY - h * 0.02f)
                path.quadTo(w * 0.5f, mouthY + h * 0.12f, w * 0.66f, mouthY - h * 0.02f)
                canvas.drawPath(path, stroke)
            }
        }
    }
}
